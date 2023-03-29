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

## 地址映射

在开启 MMU 后，需要确保在内核地址空间能够访问到 UINTC 。


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
static __always_inline void arch_exit_to_user_mode(void) { }
#endif
```

发现 riscv 并没有实现这些函数，需要我们添加头文件 `arch/riscv/include/asm/entry-common.h`。