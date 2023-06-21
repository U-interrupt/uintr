# seL4 开发日志

TODO：

- [x] (ARCH=RISCV64) 在 QEMU 上启动 seL4 ，运行 seL4test 和 seL4bench
- [ ] 尝试在不改动原有 seL4 API 的基础上，使用用户态中断机制替换 Notification 机制
- [ ] 构建用户态文件系统和设备驱动，运行 sqlite3 
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

或者可以在初始化时给出这个编译选项 `../init-build.sh -DRISCV64=1 -DSIMULATION=TRUE -DPLATFORM=qemu-riscv-virt -DOPENSBI_PLAT_ISA=rv64imafdc_zifencei` 。

最后终于在 QEMU virt 上成功运行 seL4test ：

``` log
Test suite passed. 114 tests passed. 49 tests disabled.
All is well in the universe
```

## 2023.06.19

### seL4 改动 (ZRQ 2023.6)

改动类似 Linux，包括系统调用实现和外设支持。

- include/arch/riscv/arch/uintr.h: 定义 uintr 相关结构体，声明系统调用函数接口，声明相关状态保存与恢复函数。
- include/drivers/irq/riscv_uintc.h: 定义 uintc 相关结构体，声明 uintc 读写函数。
- libsel4/include/api/syscall.xml: 定义 syscall_register_receiver 和 syscall_register_sender
- src/api/syscall.c: handleSyscall 入口，跳转到新定义的 syscall
- src/arch/c_traps.c: trap 返回前（restore_user_context 函数）插入 uintr_return 函数恢复相关寄存器
- src/arch/riscv/config.cmake: 添加 uintr.c 的编译选项
- src/arch/riscv/traps.S: 陷入汇编代码，寄存器保存，中断异常跳转
- src/arch/riscv/uintr.c: Linux 内注册结构体需要利用全局变量
  - syscall_register_receiver: 注册用户态中断接收方（每个 TCB 只能注册一次），分配 uintc 槽位，返回 uintc 下标
  - syscall_register_sender: 注册用户态中断发送方（多次注册也只初始化一次状态表），根据 uintc 下标和对应标识号分配状态表项
- tools/dts/spike.dts: 加入 uintc 设备书节点
- tools/hardware.yml: 加入 uintc 描述信息
- tools/tmp.h: 由 c_header.py 自动生成

由于目前的结构都是全局静态分配的，所以还没有实现资源的释放。

一些可能会用到的函数：

- NODE_STATE(ksCurThread) 获取当前 TCB 指针
- setRegister(tcb, a0, uintc_idx): 将 uintc_idx 作为系统调用结果返回
- restore_user_context: 出现在 slowpath, fastpath 和 init_kernel 之后
- kpptr_to_paddr 将虚拟地址翻译为物理地址

### repo 改动

参考 sel4test-manifest ，一些字段的含义如下：

- project：
  - name：关联的仓库名称
  - remote：指定隶属的 org
  - path：拉取到本地后的相对路径
  - revision：版本号或分支名称
  - upstream：和 revision 对应，如果 revision 是版本号，upstream 是该 commit 所在分支，否则 upstream 无效
- remote：表示某个 org 或仓库
  - name：名称
  - fetch：目标 url
  
修改默认配置，让 seL4 仓库和 OpenSBI 仓库都指向我们修改的版本。

## 2023.06.20

继续学习 seL4 源码，思考如何修改 Notification 。