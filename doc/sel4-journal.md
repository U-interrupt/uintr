# seL4 开发日志

TODO：

- [ ] (ARCH=RISCV64) 在 QEMU 上启动 seL4 ，运行 seL4test 和 seL4bench
- [ ] 构建用户态文件系统和设备驱动，运行 sqlite3 
- [ ] 尝试在不改动原有 seL4 API 的基础上，使用用户态中断机制替换 Notification 机制
- [ ] 在 QEMU 上对 sqlite3 进行性能评估（benchmark 可以有 YSCB 等，不同读写负载，比较系统吞吐）
- [ ] 在 Rocket Chip 上启动 seL4 ，boot 流程应该与 Linux 类似
- [ ] 在 FPGA 上对 sqlite3 进行性能评估

## 2023.06.17

学习 seL4 相关知识（内核架构、构建工具 repo 等）。

按照官方给出的说明，可正常构建并运行 x86 架构的 seL4test 。

尝试构建并运行 RISC-V 架构的 seL4test ，遇到关于编译工具链的问题 `can't link double-float modules with soft-float modules` 。

## 2023.06.18

在 riscv-gnu-toolchain 中执行 ` ./configure --prefix="${RISCV}" --enable-multilib` 然后 `make linux` 报错：

```
gnu/stubs-ilp32.h: No such file or directory
    8 | # include <gnu/stubs-ilp32.h>
```

原因可能是覆盖之前安装的内容时出现了冲突，一种办法是移除之前安装的内容，重新编译工具链。

使用编译后的工具链仍报错，发现编译 seL4 时默认指定 `-march=rv64imac_zicsr_zifencei` ，执行 `riscv64-unknown-linux-gnu-g++ --print-multi-lib` 发现工具链不支持该选项，执行 `./configure --prefix=$RISCV --enable-multilib --with-arch=rv64imac_zicsr_zifencei --with-abi=lp64` 重新编译后还是报错：

```
Error: unrecognized opcode `fence.i', extension `zifencei' required
```

原因是 OpenSBI 编译命令给的是 `PLATFORM_RISCV_ISA=rv64imafdc` ，需要 `zifencei` 扩展。在 cmake-tool/rootserver.cmake 中修改即可：

```
if(NOT OPENSBI_PLAT_ISA)
    set(OPENSBI_PLAT_ISA "rv${OPENSBI_PLAT_XLEN}imafdc_zifencei")
endif()
```

最后终于在 QEMU virt 上成功运行 seL4test ：

``` log
Test suite passed. 114 tests passed. 49 tests disabled.
All is well in the universe
```