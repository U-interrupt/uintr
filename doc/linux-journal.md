# Linux 修改日志

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

在 `etc/init.d` 文件夹下创建 `init` 并修改文件的执行权限 `sudo chmod u+x init`：

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