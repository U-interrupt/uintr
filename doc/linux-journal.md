# Linux 修改日志

## 运行 Linux

目录结构：

```txt
.
├── busybox-1.33.1
├── linux
├── opensbi
├── qemu
├── rootfs
├── rootfs.img
└── uintr-main
```

在 [`riscv-gnu-toolchain`](https://github.com/riscv-collab/riscv-gnu-toolchain) 下编译 Linux 6.0：

```sh
make ARCH=riscv CROSS_COMPILE=riscv64-unknown-linux-gnu- defconfig
make ARCH=riscv CROSS_COMPILE=riscv64-unknown-linux-gnu- -j $(nproc)
```

下载 busybox-1.33.1 版本，执行`make CROSS_COMPILE=riscv64-unknown-linux-gnu- menuconfig` 进行配置，选中 `Settings-Build Options-Build static binary (no shared libs)`：

```sh
make CROSS_COMPILE=riscv64-unknown-linux-gnu- -j $(nproc)
make CROSS_COMPILE=riscv64-unknown-linux-gnu- install
```

编译完成后出现 `_install` 文件夹，可以看到该目录下生成的了 busybox 的可执行文件。

接下来需要制作一个最小的文件系统：

```sh
qemu-img create rootfs.img 1g
mkfs.ext4 rootfs.img
```

`qemu-img` 是 qemu 生成镜像的工具，可以修改生成镜像的大小，使用 `mkfs.ext4` 工具制作文件系统镜像。

```sh
mkdir rootfs
sudo mount -o loop rootfs.img  rootfs
cd rootfs
sudo cp -r ../busybox-1.33.1/_install/* .
sudo mkdir proc sys dev etc etc/init.d
```

将 busybox 中的内容拷贝到文件系统中，并创建运行 Linux 必要的文件和目录。

在 `etc/init.d` 文件夹下创建 `rcS` 并修改文件的执行权限 `sudo chmod u+x rcS`：

```txt
#!/bin/sh

mount -t proc none /proc
mount -t sysfs none /sys
echo -e "\nBoot took $(cut -d' ' -f1 /proc/uptime) seconds\n"
/sbin/mdev -s
```

执行 `sudo umount rootfs` 卸载文件系统。

最后执行脚本：

```sh
#!/bin/bash

QEMU=./qemu/build/riscv64-softmmu/qemu-system-riscv64
LINUX=./linux/arch/riscv/boot/Image
ROOTFS=./rootfs.img

$QEMU \
    -M virt -m 256M -nographic \
    -smp 4 \
    -kernel $LINUX \
    -drive file=$ROOTFS,format=raw,id=hd0 \
    -device virtio-blk-device,drive=hd0 \
    -append "root=/dev/vda rw console=ttyS0" \
    -D qemu-linux.log
```

可以按照上述文件系统的制作流程，加入相关的测例或可执行文件。

## 开发 Linux

使用 VSCode 阅读 Linux 源码，出现大量报错，且代码跳转非常卡。不再采用 C++ intellisense 插件，使用 clangd 插件。

安装 `bear` 和 `clangd` 工具后执行：

```sh
bear -- make ARCH=riscv CROSS_COMPILE=riscv64-unknown-linux-gnu- defconfig
bear -- make ARCH=riscv CROSS_COMPILE=riscv64-unknown-linux-gnu- -j $(nproc)
```

bear 会记录项目编译过程中每个文件的编译选项，并将其记录在 `compile_commands.json` 文件中。

重新打开文件后，红波浪线消失，代码提示、代码跳转等功能工作正常。

执行 `dmesg` 查看内核日志信息，或者执行 `cat /proc/kmsg` 打印内核日志信息。

```c
#define pr_fmt(fmt) "%s: [%-25s]: " fmt, KBUILD_MODNAME, __func__
```

添加上述代码自定义日志格式，尝试在代码中调用 `pr_debug` 输出没有看到结果，阅读配置后发现默认情况下该函数不会被编译，因此采用 `pr_info` 输出内核信息。

执行 `cat /proc/sys/kernel/printk` 查看日志等级：

```txt
/ # cat /proc/sys/kernel/printk
7       4       1       7
```

这四个值定义在 `kernel/printk/printk.c` 中：

```c
int console_printk[4] = {
    CONSOLE_LOGLEVEL_DEFAULT,       /* console_loglevel */
    MESSAGE_LOGLEVEL_DEFAULT,       /* default_message_loglevel */
    CONSOLE_LOGLEVEL_MIN,           /* minimum_console_loglevel */
    CONSOLE_LOGLEVEL_DEFAULT,       /* default_console_loglevel */
};
```

## 编译选项

在 `arch/riscv/Kconfig` 中添加 `RISCV_UINTR` 相关配置：

```txt
config RISCV_UINTR
	bool "User Interrupt Support"
	default y
```

编译时即可看到相关选项，开启后成功编译出 `uintr.o`，接下来我们就可以在 `uintr.c` 中编写相关代码。

    Kconfig 语法：

    - `menu <expr>`: 定义菜单；
    - `depends on <expr>`: 表达式条件满足时，改选项才能被选中；
    - `select <symbol> [if <expr>]`: 当前选项选中后 select 指定的选项被自动选中；
    - `default <expr> [if <expr>]`: 一个配置选项可以有任意多个默认值，只有第一个是有效的；

## 访问外设

在开启 MMU 后，需要确保在内核地址空间能够访问到 UINTC 。

    Linux 多级页表：

    SV48: pgd -> pud -> pmd -> pte -> page (4K)
    SV57: pgd -> p4d -> pud -> pmd -> pte -> page (4K)

中断驱动位于 `drivers/irqchip` ，主要有两部分内容 `irq-riscv-intc.c` 和 `irq-sifive-plic.c` 。

```c
static asmlinkage void riscv_intc_irq(struct pt_regs *regs)
{
	unsigned long cause = regs->cause & ~CAUSE_IRQ_FLAG;

	if (unlikely(cause >= BITS_PER_LONG))
		panic("unexpected interrupt cause");

	switch (cause) {
#ifdef CONFIG_SMP
	case RV_IRQ_SOFT:
		/*
		 * We only use software interrupts to pass IPIs, so if a
		 * non-SMP system gets one, then we don't know what to do.
		 */
		handle_IPI(regs);
		break;
#endif
	default:
		generic_handle_domain_irq(intc_domain, cause);
		break;
	}
}
```

例如函数 `riscv_intc_irq` 对 S 态软件中断进行处理，调用 `handle_IPI` 函数。

外设的注册和设备树有关，qemu 在 virt 中会根据模拟的外设写入设备树，然而 UINTC 目前没有设备树支持。我们需要用其他的办法访问 UINTC 外设，目标是在内核地址空间增加一段 UINTC 物理地址到虚拟地址的映射，通过硬编码的方式对 UINTC 进行访问。

内核地址空间初始化位于 `arch/riscv/mm/init.c`：

```c
asmlinkage void __init setup_vm(uintptr_t dtb_pa)
{  
    // ...    
    kernel_map.virt_addr = KERNEL_LINK_ADDR;
	kernel_map.page_offset = _AC(CONFIG_PAGE_OFFSET, UL);

	kernel_map.phys_addr = (uintptr_t)(&_start);
	kernel_map.size = (uintptr_t)(&_end) - kernel_map.phys_addr;

	kernel_map.va_pa_offset = PAGE_OFFSET - kernel_map.phys_addr;
	kernel_map.va_kernel_pa_offset = kernel_map.virt_addr - kernel_map.phys_addr;
    // ...
}
```

```txt
========================================================================================================================
     Start addr    |   Offset   |     End addr     |  Size   | VM area description
========================================================================================================================
                   |            |                  |         |
  0000000000000000 |    0       | 00007fffffffffff |  128 TB | user-space virtual memory, different per mm
 __________________|____________|__________________|_________|___________________________________________________________
                   |            |                  |         |
  0000800000000000 | +128    TB | ffff7fffffffffff | ~16M TB | ... huge, almost 64 bits wide hole of non-canonical
                   |            |                  |         | virtual memory addresses up to the -128 TB
                   |            |                  |         | starting offset of kernel mappings.
 __________________|____________|__________________|_________|___________________________________________________________
                                                             |
                                                             | Kernel-space virtual memory, shared between all processes:
 ____________________________________________________________|___________________________________________________________
                   |            |                  |         |
  ffff8d7ffee00000 |  -114.5 TB | ffff8d7ffeffffff |    2 MB | fixmap
  ffff8d7fff000000 |  -114.5 TB | ffff8d7fffffffff |   16 MB | PCI io
  ffff8d8000000000 |  -114.5 TB | ffff8f7fffffffff |    2 TB | vmemmap
  ffff8f8000000000 |  -112.5 TB | ffffaf7fffffffff |   32 TB | vmalloc/ioremap space
  ffffaf8000000000 |  -80.5  TB | ffffef7fffffffff |   64 TB | direct mapping of all physical memory
  ffffef8000000000 |  -16.5  TB | fffffffeffffffff | 16.5 TB | kasan
 __________________|____________|__________________|_________|____________________________________________________________
                                                             |
                                                             | Identical layout to the 39-bit one from here on:
 ____________________________________________________________|____________________________________________________________
                   |            |                  |         |
  ffffffff00000000 |   -4    GB | ffffffff7fffffff |    2 GB | modules, BPF
  ffffffff80000000 |   -2    GB | ffffffffffffffff |    2 GB | kernel
 __________________|____________|__________________|_________|____________________________________________________________
```

内存资源初始化位于 `arch/riscv/kernel/setup.c`：

```c
/*
 * 主要初始化 code、rodata、data、bss 等物理段；
 *              iomem
 *                |
 *              kimage
 *    /       /        \       \
 *  code   rodata     data     bss
 */
static int __init add_kernel_resources(void)
{
   /*
	 * The memory region of the kernel image is continuous and
	 * was reserved on setup_bootmem, register it here as a
	 * resource, with the various segments of the image as
	 * child nodes.
	 */
}
```

`struct resource` 定义位于 `include/linux/ioport.h`：

```c
/* 物理资源通过树形结构来管理，包含起止地址、名称、描述等信息 */
struct resource {
	resource_size_t start;
	resource_size_t end;
	const char *name;
	unsigned long flags;
	unsigned long desc;
	struct resource *parent, *sibling, *child;
};
```

发现 `init_resources` 函数并没有向 `iomem` 插入外设，说明在其他的地方进行了初始化。

发现 io 物理地址映射与架构无关，位于 `include/asm-generic/io.h` 和 `mm/ioremap.c`：

```c
void __iomem *ioremap_prot(phys_addr_t phys_addr, size_t size,
			   unsigned long prot);
void iounmap(volatile void __iomem *addr);

static inline void __iomem *ioremap(phys_addr_t addr, size_t size)
{
	/* _PAGE_IOREMAP needs to be supplied by the architecture */
	return ioremap_prot(addr, size, _PAGE_IOREMAP);
}
```

通过在 `ioremap_prot` 函数中打印日志定位到 plic 在这个函数中进行了初始化：

```log
[    0.000000] before irqchip_init
[    0.000000] before of_irq_init
[    0.000000] riscv-intc: 64 local interrupts mapped
[    0.000000] ioremap_prot 0xc000000 0x600000
[    0.000000] plic: plic@c000000: mapped 53 interrupts with 4 handlers for 8 contexts.
[    0.000000] after of_irq_init
[    0.000000] after irqchip_init
```

注：**of（Open Firmware）**

初始化在 `of_irq_init` 中完成：

```c
/**
 * of_irq_init - Scan and init matching interrupt controllers in DT
 * @matches: 0 terminated array of nodes to match and init function to call
 *
 * This function scans the device tree for matching interrupt controller nodes,
 * and calls their initialization functions in order with parents first.
 */
void __init of_irq_init(const struct of_device_id *matches)
{
	for_each_matching_node_and_match(np, matches, &match) {
        /* 遍历设备树，将设备树信息解析为 device_node 放入 intc_desc_list */
	}

	/*
	 * The root irq controller is the one without an interrupt-parent.
	 * That one goes first, followed by the controllers that reference it,
	 * followed by the ones that reference the 2nd level controllers, etc.
	 */
	while (!list_empty(&intc_desc_list)) {
		/*
		 * Process all controllers with the current 'parent'.
		 * First pass will be looking for NULL as the parent.
		 * The assumption is that NULL parent means a root controller.
		 */
		list_for_each_entry_safe(desc, temp_desc, &intc_desc_list, list) {
            /* 调用 irq_init_cb  完成初始化 */
			ret = desc->irq_init_cb(desc->dev,
						desc->interrupt_parent);
		}
	}
}
```

Linux 关于 HLIC （Hart-Level Interrupt Controller） 的[文档](https://elixir.bootlin.com/linux/latest/source/Documentation/devicetree/bindings/interrupt-controller/riscv,cpu-intc.txt)：

Required properties:

- compatible : "riscv,cpu-intc"
- #interrupt-cells : should be <1>.  The interrupt sources are defined by the
  RISC-V supervisor ISA manual, with only the following three interrupts being
  defined for supervisor mode:
    - Source 1 is the supervisor software interrupt, which can be sent by an SBI
      call and is reserved for use by software.
    - Source 5 is the supervisor timer interrupt, which can be configured by
      SBI calls and implements a one-shot timer.
    - Source 9 is the supervisor external interrupt, which chains to all other
      device interrupts.
- interrupt-controller : Identifies the node as an interrupt controller

例如 QEMU 中生成的一段设备树信息：

```txt
cpu@0 {
    phandle = <0x07>;
    device_type = "cpu";
    reg = <0x00>;
    status = "okay";
    compatible = "riscv";
    riscv,isa = "rv64imafdcnsuh";
    mmu-type = "riscv,sv48";

    interrupt-controller {
        #interrupt-cells = <0x01>;
        interrupt-controller;
        compatible = "riscv,cpu-intc";
        phandle = <0x08>;
    };
};
```

在 Linux 中，采用两个 ID 来标识一个来自外设的中断：

1. IRQ number：CPU 为每个外设中断编号，和硬件无关；
2. HW interrupt ID：对于 interrupt controller 而言，它收集了多个外设的 interrupt request line 并向上传递，在 interrupt controller 级联的情况下，使用 HW interrupt ID 并不能唯一标识一个外设中断，因此 Linux 中断子系统需要对来自不同 interrupt controller 的 HW interrupt ID 进行管理和映射。

我们的实现不会涉及到 ID 的注册，因此暂时不需要考虑 IRQ domain 。

发现 `irq_chip` 结构封装了一系列的 op，对照 `irq-riscv-intc.c` 和 `irq-sifive-plic.c` 进行学习：

例如 `riscv_intc_irq_mask` 和 `riscv_intc_irq_unmask` 中对 CSR sie 对应位进行操作。

在 QEMU 中生成 UINTC 设备树信息：

```c
static void create_fdt_socket_uintc(RISCVVirtState *s,
                                    const MemMapEntry *memmap, int socket,
                                    uint32_t *phandle,
                                    uint32_t *intc_phandles) {
    int cpu;
    char *uintc_name;
    uint32_t *uintc_cells;
    unsigned long uintc_addr;
    MachineState *mc = MACHINE(s);
    static const char *const uintc_compat[1] = {"riscv,uintc0"};

    uintc_cells = g_new0(uint32_t, s->soc[socket].num_harts * 2);

    for (cpu = 0; cpu < s->soc[socket].num_harts; cpu++) {
        uintc_cells[cpu * 2 + 0] = cpu_to_be32(intc_phandles[cpu]);
        uintc_cells[cpu * 2 + 1] = cpu_to_be32(IRQ_U_SOFT);
    }

    uintc_addr = memmap[VIRT_UINTC].base + (memmap[VIRT_UINTC].size * socket);
    uintc_name = g_strdup_printf("/soc/uintc@%lx", uintc_addr);
    qemu_fdt_add_subnode(mc->fdt, uintc_name);
    qemu_fdt_setprop_string_array(mc->fdt, uintc_name, "compatible",
                                  (char **)&uintc_compat,
                                  ARRAY_SIZE(uintc_compat));
    qemu_fdt_setprop(mc->fdt, uintc_name, "interrupt-controller", NULL, 0);
    qemu_fdt_setprop_cells(mc->fdt, uintc_name, "reg", 0x0, uintc_addr, 0x0,
                           memmap[VIRT_UINTC].size);
    qemu_fdt_setprop(mc->fdt, uintc_name, "interrupts-extended", uintc_cells,
                     s->soc[socket].num_harts * sizeof(uint32_t) * 2);
    riscv_socket_fdt_write_id(mc, mc->fdt, uintc_name, socket);
    g_free(uintc_name);

    g_free(uintc_cells);
}
```

最后生成的设备树节点内容：

```txt
uintc@2f10000 {
    interrupts-extended = <0x08 0x00 0x06 0x00 0x04 0x00 0x02 0x00>;
    reg = <0x00 0x2f10000 0x00 0x4000>;
    interrupt-controller;
    compatible = "riscv,uintc0";
};
```

Linux 会在初始化 `interrupt-controller` 的过程中调用 UINTC 驱动的初始化函数 `static int __init uintc_init(struct device_node *node, struct device_node *parent)`。

```c
static int __init uintc_init(struct device_node *node,
			     struct device_node *parent)
{
	int error = 0, nr_contexts, i;
	struct uintc_priv *priv;
	struct uintc_handler *handler;
	struct resource uintc_res;

    // 初始化 UINTC 的控制结构 struct uintc_priv
	priv = kzalloc(sizeof(*priv), GFP_KERNEL);
	if (!priv)
		return -ENOMEM;

    // 解析设备树得到外设的物理地址空间
	if (of_address_to_resource(node, 0, &uintc_res)) {
		error = -EIO;
		goto out_free;
	}

	/* Initialize suicfg resgiter for U-mode UIPI instruction  */
	csr_write(CSR_SUICFG, uintc_res.start);

    // 将外设信息保存在 struct uintc_priv 中
	priv->size = resource_size(&uintc_res);
	priv->nr = priv->size / UINTC_WIDTH;
    // 调用 ioremap 函数完成内核物理地址到虚拟地址的映射，这样就可以在之后访问虚拟地址完成对 UITNC 的操作
	priv->regs = ioremap(uintc_res.start, priv->size);
	if (WARN_ON(!priv->regs)) {
		error = -EIO;
		goto out_free;
	}

    // 全局 bitmap 用来分配 UINTC 中的接收方状态
	priv->mask = bitmap_alloc(priv->nr, GFP_KERNEL);
	if (!priv->mask) {
		error = -ENOMEM;
		goto out_iounmap;
	}

	error = -EINVAL;
	nr_contexts = of_irq_count(node);
	if (WARN_ON(!nr_contexts))
		goto out_iounmap;

    // 这里参考了 plic 外设的初始化过程，对父节点 Local INTC 进行遍历
    // 初始化每个核上的控制结构 struct uintc_handler TODO
	for (i = 0; i < nr_contexts; i++) {
		struct of_phandle_args parent;
		int cpu;
		unsigned long hartid;

		if (of_irq_parse_one(node, i, &parent)) {
			pr_err("failed to parse parent for context %d.\n", i);
			continue;
		}

		if (parent.args[0] != IRQ_U_SOFT) {
			continue;
		}

		error = riscv_of_parent_hartid(parent.np, &hartid);
		if (error < 0) {
			pr_warn("failed to parse hart ID for context %d.\n", i);
			continue;
		}

		cpu = riscv_hartid_to_cpuid(hartid);
		if (cpu < 0) {
			pr_warn("invalid cpuid for context %d.\n", i);
			continue;
		}

		handler = per_cpu_ptr(&uintc_handlers, cpu);
		if (handler->present) {
			pr_warn("handler already present for context %d.\n", i);
			continue;
		}

		cpumask_set_cpu(cpu, &priv->lmask);
		handler->present = true;
		handler->priv = priv;
	}

	pr_info("%pOFP: %d entries available\n", node, priv->nr);
	return 0;

out_iounmap:
	iounmap(priv->regs);
out_free:
	kfree(priv);
	return error;
}
```

最后再通过定义一系列的操作函数就可以在内核对外设进行访问了：

```c
int uintc_alloc(void);
int uintc_dealloc(int index);

int uintc_send(int index);
int uintc_write_low(int index, u64 value);
int uintc_read_low(int index, u64 *value);
int uintc_write_high(int index, u64 value);
int uintc_read_high(int index, u64 *value);
```

## 状态保存与恢复

在 `linux/include/linux/entry-common.h` 中实现为空函数，不同 ARCH 可以注册并实现。

```c
/**
 * arch_enter_from_user_mode - Architecture specific sanity check for user mode regs
 * @regs:	Pointer to currents pt_regs
 *
 * Defaults to an empty implementation. Can be replaced by architecture
 * specific code.
 *
 * Invoked from syscall_enter_from_user_mode() in the non-instrumentable
 * section. Use __always_inline so the compiler cannot push it out of line
 * and make it instrumentable.
 */
static __always_inline void arch_enter_from_user_mode(struct pt_regs *regs);

#ifndef arch_enter_from_user_mode
static __always_inline void arch_enter_from_user_mode(struct pt_regs *regs) {}
#endif

/**
 * arch_exit_to_user_mode - Architecture specific final work before exit to user mode.
 *
 * Invoked from exit_to_user_mode() with interrupt disabled as the last
 * function before return. Defaults to NOOP.
 *
 * An architecture implementation must not do anything complex, no locking
 * etc. The main purpose is for speculation mitigations.
 */
static __always_inline void arch_exit_to_user_mode(void);

#ifndef arch_exit_to_user_mode
static __always_inline void arch_exit_to_user_mode(void) {}
#endif
```

发现 riscv 并没有实现这些函数，需要我们添加头文件 `arch/riscv/include/asm/entry-common.h`。