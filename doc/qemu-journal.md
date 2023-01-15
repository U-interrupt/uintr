# QEMU

> QEMU does not have a high level design description document - only the source code tells the full story. (From QEMU wiki)

QEMU 中已经有大量 API 的文档，主要位于 `docs` 目录下。

## x86 复现

启动 Linux 遇到问题，和 xcd 交流后发现可能 Qemu 和 Linux 需要切换到合适的分支上才能正常工作，经过尝试后，目前采用的分支为：

- [QEMU](https://github.com/OS-F-4/qemu-uintr/commit/8077f13cc8d37d229ced48755084563ec94b94c6)
- [Linux](https://github.com/OS-F-4/uintr-linux-kernel/commit/6015080e9ea64f9304f17f610d736cb1ed52924f)

已有文档非常详细，主要分为以下几个步骤：

- [编译 QEMU](https://github.com/OS-F-4/usr-intr/blob/main/ppt/%E5%B1%95%E7%A4%BA%E6%96%87%E6%A1%A3/qemu.md)
- [编译 Linux](https://github.com/OS-F-4/usr-intr/blob/main/ppt/%E5%B1%95%E7%A4%BA%E6%96%87%E6%A1%A3/linux-kernel.md)
- [构建文件系统](https://github.com/OS-F-4/usr-intr/blob/main/ppt/how-to-build-a-ubuntu-rootfs.md)

目前可运行的测例：Linux 自带的 uipi_sample

阅读 Linux 关于 UINTR 系统调用的实现可以注意到，接收方在满足以下条件时可以响应中断：

- 正在被当前核调度，直接进入注册好的用户态中断处理函数
- 通过系统调用 `sys_uintr_wait` 让权后，接收方进程等待被内核调度后再进入中断处理函数
- 时间片用尽后被内核重新放入调度队列，接收方等待重新被内核调度后再进入中断处理函数

```c
int uintr_receiver_wait(void)
{
    struct uintr_upid_ctx *upid_ctx;
    unsigned long flags;

    if (!is_uintr_receiver(current))
        return -EOPNOTSUPP;

    upid_ctx = current->thread.ui_recv->upid_ctx;
    // 发送方将中断发给内核
    upid_ctx->upid->nc.nv = UINTR_KERNEL_VECTOR;
    // 接收方进入 waiting 状态
    upid_ctx->waiting = true;
    // 交给统一的调度队列 uintr_wait_list 进行管理，内核收到用户态中断后会遍历队列进行处理
    spin_lock_irqsave(&uintr_wait_lock, flags);
    list_add(&upid_ctx->node, &uintr_wait_list);
    spin_unlock_irqrestore(&uintr_wait_lock, flags);
    // 修改当前 task 的状态为 INTERRUPTIBLE
    set_current_state(TASK_INTERRUPTIBLE);
    // 运行下一个 task
    schedule();

    return -EINTR;
}
```

目前定义了两种 User Interrupt Notification：

- `UINTR_NOTIFICATION_VECTOR`: 0xec
- `UINTR_KERNEL_VECTOR`: 0xeb

关于 `UINTR_KERNEL_VECTOR` 的用途，注意到：

```c
/*
 * Handler for UINTR_KERNEL_VECTOR.
 */
DEFINE_IDTENTRY_SYSVEC(sysvec_uintr_kernel_notification)
{
    /* TODO: Add entry-exit tracepoints */
    ack_APIC_irq();
    inc_irq_stat(uintr_kernel_notifications);

    uintr_wake_up_process();
}
/*
 * Runs in interrupt context.
 * Scan through all UPIDs to check if any interrupt is on going.
 */
void uintr_wake_up_process(void)
{
    struct uintr_upid_ctx *upid_ctx, *tmp;
    unsigned long flags;

    // 遍历 uintr_wait_list
    spin_lock_irqsave(&uintr_wait_lock, flags);
    list_for_each_entry_safe(upid_ctx, tmp, &uintr_wait_list, node) {
        if (test_bit(UPID_ON, (unsigned long *)&upid_ctx->upid->nc.status)) {
            set_bit(UPID_SN, (unsigned long *)&upid_ctx->upid->nc.status);
            upid_ctx->upid->nc.nv = UINTR_NOTIFICATION_VECTOR;
            upid_ctx->waiting = false;
            wake_up_process(upid_ctx->task);
            list_del(&upid_ctx->node);
        }
    }
    spin_unlock_irqrestore(&uintr_wait_lock, flags);
}
```

每当 task 被重新调度并返回 user space 前，执行以下函数：

```c
void switch_uintr_return(void)
{
    struct uintr_upid *upid;
    u64 misc_msr;

    if (is_uintr_receiver(current)) {
        WARN_ON_ONCE(test_thread_flag(TIF_NEED_FPU_LOAD));

        /* Modify only the relevant bits of the MISC MSR */
        rdmsrl(MSR_IA32_UINTR_MISC, misc_msr);
        if (!(misc_msr & GENMASK_ULL(39, 32))) {
            misc_msr |= (u64)UINTR_NOTIFICATION_VECTOR << 32;
            wrmsrl(MSR_IA32_UINTR_MISC, misc_msr);
        }

        /*
        因为此时 task 被重新调度，需要更新 ndst 对应的 APIC ID
        同时需要清空 SN 来允许接收中断
        */
        upid = current->thread.ui_recv->upid_ctx->upid;
        upid->nc.ndst = cpu_to_ndst(smp_processor_id());
        clear_bit(UPID_SN, (unsigned long *)&upid->nc.status);

        /*
        UPID_SN 已经被清空，此时可以接收新的中断
        为了让 task 能知道自己在等待的过程中收到了发送方发过来的中断，直接调用 send_IPI_self 触发硬件处理流程： User-Interrupt Notification Identification 和 User-Interrupt Notification Processing；
        另一种办法是软件进行处理来触发中断，即清空 UPID.PUIR 和 写入 UIRR 寄存器，代码注释提示软件触发中断需要处理和硬件修改 UPID 之间的竞争；
        根据 intel 文档的描述，以下任何一种情况都可以触发 recognition of pending user interrupt:
        1. 写入 IA32_UINTR_RR_MSR
        4. User-interrupt notification processing: 也就是收到中断后硬件处理
        */
        if (READ_ONCE(upid->puir))
            apic->send_IPI_self(UINTR_NOTIFICATION_VECTOR);
    }
}

```

在 manpages 中注意到这样一段描述：

```txt
A receiver can choose to share the same uintr_fd with multiple senders.
Since an interrupt with the same vector number would be delivered,  the
receiver  would  need  to  use  other  mechanisms to identify the exact
source of the interrupt.
```

大致意思是说不同的 sender 可能是拿同一个 fd 注册的 uitte ，需要 receiver 应用其他方法来区分 sender 。
处于同一个中断优先级的 sender 彼此之间无法通过已有机制加以区分，那么这种区分是否是必要的？

## RISC-V 实现

QEMU RISC-V 的实现架构和 x86 的有很大不同。

编译：`./configure --target-list=riscv64-softmmu && make`。

关于 GDB 调试，之前写 os 的调试方法可以直接在这里应用。

主要关注几个方面：

- 指令翻译
- CPU 状态
- 内存读写
- 核间中断

主要参考 [QEMU RISC-V N扩展](https://github.com/duskmoon314/qemu) 的相关实现。

### 指令翻译（Code Generation）

QEMU 指令翻译的过程：`Guest Instructions -> TCG (Tiny Code Generator) ops -> Host Instructions`

主要关注 `TCG Frontend`，也就是 QEMU 将 Guest 的指令翻译成 TCG 中间码的部分。

代码核心部分位于 `traget/riscv/translate.c`，开头部分定义了 `DisasContext`，该文件给出了一些常用的工具函数。

RISC-V 指令集扩展模块化，QEMU 在翻译指令的时候也按照这个逻辑处理。

### CPU 状态（Target Emulation）

中断异常、CSR、CSR bits 等定义位于 `target/riscv/cpu_bits.h` 。

`struct CPUArchState`：CPU 状态结构体位于 `target/riscv/cpu.h`。这个结构同时考虑了 RV32、RV64、RV128 的情况，具体可以参考结构体内部的注释。与在 FPGA 上开发硬件类似，这些寄存器都是 CPU 运行时必要的状态。包括但不限于：

- PC
- 整数、浮点寄存器堆
- CSR 特权寄存器，有些寄存器是 M 态和 S 态复用的，例如 `mstatus`、 `mip` 等
- PMP 寄存器堆 `pmp_table_t`
- `QEMUTimer *timer`：计时器
- 通过 `kernel_addr`、`fdt_addr` 等从指定位置加载镜像

`struct RISCVCPUConfig`：主要包含各种 CPU 特性的开关，包括但不限于：

- 扩展类型
- 是否开启 MMU
- 是否开启 PMP

`struct ArchCPU`：对 CPU 的进一步封装。

```c
struct ArchCPU {
    // 全局的 CPU 状态，类似于继承关系，可以暂时不考虑
    CPUState parent_obj;
    CPUNegativeOffsetState neg;
    // 主要修改这一部分内容
    CPURISCVState env;
    char *dyn_csr_xml;
    char *dyn_vreg_xml;
    // 可以加入我们自己设计的扩展选项
    RISCVCPUConfig cfg;
};
```

CSR 的修改主要位于 csr.c 。

```c
riscv_csr_operations csr_ops[CSR_TABLE_SIZE];

typedef struct {
    const char *name;
    riscv_csr_predicate_fn predicate;
    riscv_csr_read_fn read;
    riscv_csr_write_fn write;
    riscv_csr_op_fn op;
    riscv_csr_read128_fn read128;
    riscv_csr_write128_fn write128;
} riscv_csr_operation s;
```

这个结构体给出了针对 CSR 寄存器进行的操作。

读写 csr 寄存器定义在 `target/riscv/cpu.h` ，实现在 `target/riscv/csr.c`。

```c
/*
 * riscv_csrrw - read and/or update control and status register
 *
 * csrr   <->  riscv_csrrw(env, csrno, ret_value, 0, 0);
 * csrrw  <->  riscv_csrrw(env, csrno, ret_value, value, -1);
 * csrrs  <->  riscv_csrrw(env, csrno, ret_value, -1, value);
 * csrrc  <->  riscv_csrrw(env, csrno, ret_value, 0, value);
 */
RISCVException riscv_csrrw(CPURISCVState *env, int csrno,
                           target_ulong *ret_value,
                           target_ulong new_value, target_ulong write_mask)
{
    RISCVCPU *cpu = env_archcpu(env);

    // 检查是否尝试写入只读 CSR，是否开启 CSR
    // 这个函数最后会返回 csr_ops[csrno].predicate(env, csrno)
    // 12.14：暂时没明白 riscv_csr_predicate_fn 是干什么的，可能是一些指令集相关的检查
    RISCVException ret = riscv_csrrw_check(env, csrno, write_mask, cpu);
    if (ret != RISCV_EXCP_NONE) {
        return ret;
    }

    // 先检查该 CSR 是否存在特殊的 csrrw 处理函数
    // CSR 必须注册 riscv_csr_read_fn
    // 尝试读旧值（可能触发异常），根据注释中描述的参数情况，如果 write mask 不为 0,将新值 mask 运算之后写入（可能触发异常）
    // 根据 csrrw 语义，写入新值，返回旧值
    return riscv_csrrw_do64(env, csrno, ret_value, new_value, write_mask);
}
```

`target/riscv/cpu.h` 文件末尾有一个大表，里面列出了每个 CSR 的操作函数，直接在这里定义即可。

在 `target/riscv/cpu_helper.c` 中有这样一个函数将 pending 的 interrupt 转换成 irq 来触发 CPU 中断处理机制：

```c
static int riscv_cpu_all_pending(CPURISCVState *env) {
    return env->mip & env->mie;
}
/* 
主要关注两个参数 extirq_def_prio 和 iprio
先判断是否开启 AIA ，如果没有开启，则直接计算尾 0， 然后返回 irq
如果开启 AIA ，先计算特权级
    默认拿到 iprio[irq] 索引，若为 0
        如果是外部中断 extirq ，就赋值为 extirq_def_prio，否则根据 default_iprio 表中的信息拿到
按以上的方法，从右向左遍历，过程中获取最合适的 irq 返回处理
*/
static int riscv_cpu_pending_to_irq(CPURISCVState *env,
                                    int extirq, unsigned int extirq_def_prio,
                                    uint64_t pending, uint8_t *iprio);
/*
先获取对应特权态的 status 中断位，确认中断是否开启
然后按特权态由高到低的顺序对 riscv_cpu_all_pending 获得的 pending 进行处理
最后调用 riscv_cpu_pending_to_irq 返回中断请求 irqs
*/
static int riscv_cpu_local_irq_pending(CPURISCVState *env);
```

有关 AIA ，详见 [RISC-V AIA](https://github.com/riscv/riscv-aia)。

CPU 中断异常处理函数位于 `target/riscv/cpu_helper.c` 的最后，这个函数只给出了 M 态和 S 态的中断异常处理，之后在此处加入委托给 U 态的中断异常处理，也就是读写 RISC-V N 扩展中提到的 `ustatus`，`ucause`，`uepc` 等寄存器。

```c
/*
计算 async 来判断是中断还是异常，以及中断或异常委托
根据 env->priv 进一步区分中断异常原因，例如 ECALL 类型
根据不同中断异常原因，设置 CPUArchState 中的状态寄存器，例如 `pc`， `stval`，`sepc` 等
根据 env->priv 设置不同的特权态对应的寄存器，例如需要区分 mstatus 和 sstatus
*/
void riscv_cpu_do_interrupt(CPUState *cs);
```

### 内存读写（Memory Emulation）

在 `target/riscv/cpu_helper.c` 中发现地址翻译的函数：

```c
/* get_physical_address - get the physical address for this virtual address
 *
 * Do a page table walk to obtain the physical address corresponding to a
 * virtual address. Returns 0 if the translation was successful
 *
 * Adapted from Spike's mmu_t::translate and mmu_t::walk
 *
 * @env: CPURISCVState
 * @physical: This will be set to the calculated physical address
 * @prot: The returned protection attributes
 * @addr: The virtual address to be translated
 * @fault_pte_addr: If not NULL, this will be set to fault pte address
 *                  when a error occurs on pte address translation.
 *                  This will already be shifted to match htval.
 * @access_type: The type of MMU access
 * @mmu_idx: Indicates current privilege level
 * @first_stage: Are we in first stage translation?
 *               Second stage is used for hypervisor guest translation
 * @two_stage: Are we going to perform two stage translation
 * @is_debug: Is this access from a debugger or the monitor?
 */
static int get_physical_address(CPURISCVState *env, hwaddr *physical,
                                int *prot, target_ulong addr,
                                target_ulong *fault_pte_addr,
                                int access_type, int mmu_idx,
                                bool first_stage, bool two_stage,
                                bool is_debug) {
/*
two stage 涉及更富杂的虚拟化的内容，也就是两级 MMU ，暂时先不考虑
这里的物理地址映射交给 QEMU 进行管理
先根据 env->satp 拿到页表基址
和内核查页表的逻辑差不多，把虚拟地址切分开，然后一级一级循环查下去
主要的复杂性在于根据 CPU 的配置区分不同的 RV 虚存机制，检查各种标志位的合法性
查询失败返回 TRANSLATE_FAIL
*/                              
}
```

x86 的设计中 `SENDUIPI index` 这个指令会根据 `UITTADDR` 寄存器，索引到内存中 `UITTADDR + index * sizeof(UITTE)` 的位置。这条指令在执行时，会直接拿到地址向内存发起读写请求，不会经过也没必要经过 MMU。

QEMU 内存读写函数 `void cpu_physical_memory_rw(hwaddr addr, void *buf, hwaddr len, bool is_write)` 位于 `softmmu/physmem.c`。

### 核间中断 (Hardware Emulation)

#### RISC-V AIA，ACLINT

有关 MSI (Message Signalled Interrupts):

- 传统发中断 pin-based out-of-band ：外设有单独引脚，独立于数据总线
- MSI：处理器和外设之间存在中断控制器，外设通过数据总线给控制器发送更丰富的中断信息，控制器进行处理后再发给处理器，这些信息可以帮助外设和控制器更好地决策发送中断的时机、目标等。
- 可以增加中断数量
- pin-based interrupt 和 posted-write 之间的竞争问题：PCI 内存控制器可能会推迟写入 DMA，导致处理器收到中断后立即尝试通过 DMA 读取旧的数据，所以中断控制器需要读取 PCI 内存控制器来判读写入是否完成。MSI write 和 DMA write 之间共用总线，所以不会出现这种异步的竞争问题。

AIA （RISC-V Advanced Interrupt Architecture）

官方文档给出了设计目标

> This RISC-V ACLINT specification defines a set of memory mapped devices which provide inter-processor interrupts (IPI) and timer functionalities for each HART on a multi-HART RISC-V platform.

QEMU 中也给出了相关实现，主要在 `hw/intc` 目录下，有关 RISC-V 的两个几个文件 `riscv_aclint.c`, `riscv_aplic.c` 和 `riscv_imsic.c` 。

```c
typedef struct RISCVAclintSwiState {
    /*< private >*/
    SysBusDevice parent_obj;

    /*< public >*/
    MemoryRegion mmio;
    // 起始 hartid
    uint32_t hartid_base;
    // hart 总数量
    uint32_t num_harts;
    uint32_t sswi;
    qemu_irq *soft_irqs;
} RISCVAclintSwiState;
```

CPU 读 SWI 寄存器的函数如下：

```c
static uint64_t riscv_aclint_swi_read(void *opaque, hwaddr addr,
    unsigned size)
{
    RISCVAclintSwiState *swi = opaque;
    // 首先保证读地址在对应 hart 范围内
    if (addr < (swi->num_harts << 2)) {
        // 获取对应 hartid
        size_t hartid = swi->hartid_base + (addr >> 2);
        // 获取对应 CPU 状态
        CPUState *cpu = qemu_get_cpu(hartid);
        CPURISCVState *env = cpu ? cpu->env_ptr : NULL;
        if (!env) {
            qemu_log_mask(LOG_GUEST_ERROR,
                          "aclint-swi: invalid hartid: %zu", hartid);
        } else if ((addr & 0x3) == 0) {
            // 返回 SWI 寄存器状态
            return (swi->sswi) ? 0 : ((env->mip & MIP_MSIP) > 0);
        }
    }

    qemu_log_mask(LOG_UNIMP,
                  "aclint-swi: invalid read: %08x", (uint32_t)addr);
    return 0;
}
```

CPU 写 SWI 寄存器的函数如下：

```c
static void riscv_aclint_swi_write(void *opaque, hwaddr addr, uint64_t value,
        unsigned size)
{
    RISCVAclintSwiState *swi = opaque;
    // 首先保证读地址在对应 hart 范围内
    if (addr < (swi->num_harts << 2)) {
        // 获取对应 hartid
        size_t hartid = swi->hartid_base + (addr >> 2);
        // 获取对应 CPU 状态
        CPUState *cpu = qemu_get_cpu(hartid);
        CPURISCVState *env = cpu ? cpu->env_ptr : NULL;
        if (!env) {
            qemu_log_mask(LOG_GUEST_ERROR,
                          "aclint-swi: invalid hartid: %zu", hartid);
        } else if ((addr & 0x3) == 0) {
            if (value & 0x1) {
                // 触发 IRQ ，调用对应 handler 对中断事务进行处理
                qemu_irq_raise(swi->soft_irqs[hartid - swi->hartid_base]);
            } else {
                if (!swi->sswi) {
                    // 清空 IRQ
                    qemu_irq_lower(swi->soft_irqs[hartid - swi->hartid_base]);
                }
            }
            return;
        }
    }

    qemu_log_mask(LOG_UNIMP,
                  "aclint-swi: invalid write: %08x", (uint32_t)addr);
}
```

QEMU 中每个 memory mapped device 都要对应到 `MemoryRegionOps`：

```c
static const MemoryRegionOps riscv_aclint_swi_ops = {
    .read = riscv_aclint_swi_read,
    .write = riscv_aclint_swi_write,
    .endianness = DEVICE_LITTLE_ENDIAN,
    .valid = {
        .min_access_size = 4,
        .max_access_size = 4
    }
};
```

调用 `memory_region_init_io`后，对该内存区域的读写就会转发给注册后的函数进行处理。

#### QEMU RISC-V VirtIO Board

通过 `-machine virt` 选中，通过 VirtIO 模拟硬件环境，代码位置 `hw/riscv/virt.c`。

从代码中可以看出一系列外设对应的地址：

```c
static const MemMapEntry virt_memmap[] = {
    [VIRT_DEBUG] =        {        0x0,         0x100 },
    [VIRT_MROM] =         {     0x1000,        0xf000 },
    [VIRT_TEST] =         {   0x100000,        0x1000 },
    [VIRT_RTC] =          {   0x101000,        0x1000 },
    [VIRT_CLINT] =        {  0x2000000,       0x10000 },
    [VIRT_ACLINT_SSWI] =  {  0x2F00000,        0x4000 },
    [VIRT_PCIE_PIO] =     {  0x3000000,       0x10000 },
    [VIRT_PLATFORM_BUS] = {  0x4000000,     0x2000000 },
    [VIRT_PLIC] =         {  0xc000000, VIRT_PLIC_SIZE(VIRT_CPUS_MAX * 2) },
    [VIRT_APLIC_M] =      {  0xc000000, APLIC_SIZE(VIRT_CPUS_MAX) },
    [VIRT_APLIC_S] =      {  0xd000000, APLIC_SIZE(VIRT_CPUS_MAX) },
    [VIRT_UART0] =        { 0x10000000,         0x100 },
    [VIRT_VIRTIO] =       { 0x10001000,        0x1000 },
    [VIRT_FW_CFG] =       { 0x10100000,          0x18 },
    [VIRT_FLASH] =        { 0x20000000,     0x4000000 },
    [VIRT_IMSIC_M] =      { 0x24000000, VIRT_IMSIC_MAX_SIZE },
    [VIRT_IMSIC_S] =      { 0x28000000, VIRT_IMSIC_MAX_SIZE },
    [VIRT_PCIE_ECAM] =    { 0x30000000,    0x10000000 },
    [VIRT_PCIE_MMIO] =    { 0x40000000,    0x40000000 },
    [VIRT_DRAM] =         { 0x80000000,           0x0 },
};
```

其中涉及核间中断的外设为 `VIRT_PLIC` ，`VIRT_CLINT` 和 `VIRT_ACLINT_SSWI` ，当然也可以自己注册某些外设。其中可以看到我们比较熟悉的 `VIRT_VIRTIO` 地址映射 `0x10001000, 0x1000` 。

`virt_machine_init` 函数负责初始化 CPU ，外设等。

```c
static void virt_machine_init(MachineState *machine) {
/*
预分配一块内存用于存储设备的地址映射
    MemoryRegion *system_memory = get_system_memory();
根据 CPU 插槽数进行遍历，实际 hart 数量由 smp 参数指定，关于这一部分在 hw/riscv/numa.c：
调用 riscv_aclint_swi_create 建立对 VIRT_ACLINT_SSWI 和 VIRT_CLINT 的映射，并初始化 mtimer
根据 s->aia_type 进行判断，如果是 VIRT_AIA_TYPE_NONE 就调用 virt_create_plic 初始化 PLIC
否则调用 virt_create_aia 初始化 AIA

接下来调用一系列函数进行外设初始化：
virt_create_aia 初始化中断控制器
memory_region_add_subregion 初始化 RAM 和 Boot ROM
sysbus_create_simple 将 VirtIO 外设接入
gpex_pcie_init 初始化 VIRT_PCIE_ECAM 和 VIRT_PCIE_MMIO
serial_mm_init 初始化串口 VIRT_UART0
virt_flash_create, virt_flash_map 初始化 flash

最后根据地址映射创建设备树交给上层应用 create_fdt
*/
}
```
