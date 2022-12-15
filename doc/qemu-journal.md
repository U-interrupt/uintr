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
