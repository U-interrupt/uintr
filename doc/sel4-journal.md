# seL4 开发日志

TODO：

- [x] (ARCH=RISCV64) 在 QEMU 上启动 seL4 ，运行 seL4test 和 seL4bench
- [x] 尝试在不改动原有 seL4 API 的基础上，使用用户态中断机制替换 Notification 机制
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

## 2023.07.05

在 `build` 目录下执行 `ccmake .` 进入图形界面对编译选项进行配置，设置 MAX_NODES 和 SMP 后并编译发现 `simulate` 启动卡住，问题出现在 elfloader-tool 的 arch-riscv 启动流程 boot.c 中。主要函数是 `run_elfloader`，如果编译选项 NUM_NODES 大于 1 ，主核就会执行 `sbi_hart_start` 唤醒从核，从核入口为 `crt0.S` 中的 `secondary_harts`，从核跳转到 `secondary_entry` 前会进行栈初始化。主从核都会执行 `set_and_wait_for_ready` 来设置 `core_ready[core_id]` 并等待所有核都将该位设置为 1 。默认的 simulate 执行时未指定 `-smp` 选项，因此 opensbi 仅识别到了一个核，并只在一个核上启动了 elfloader ，导致主核卡在等待从核启动的循环处，手动运行 qemu 可以解决这个问题。

开启 MCS 和 SMP 后 kernel 启动报错：`seL4 failed assertion 't0 <= margin + t && t <= t0 + margin' at /home/tkf/Code/os/seL4/sel4test2/kernel/src/kernel/boot.c:563 in function clock_sync_test` ，可能是时钟不匹配，跳过这里后卡在 `SCHED_CONTEXT_0014` 测例。

补充 seL4 源码阅读文档。

## 2023.07.10

seL4 的 Notification 机制一共有三个函数，分别是 Send ，Wait，Poll 。在 riscv 的 lib 库中，Wait 和 Poll 分别调用了 Recv 和 NBRecv 。NBRecv 是指如果不处于 Active 状态就直接返回 0 。Notification 的设计初衷是一种跨进程的同步机制，也就是说通信的接收方需要显式地获取 badge 中包含的信息。对于正在两个核上运行的进程或线程来说，平均每次通信至少需要两次陷入的时间（阻塞的 Recv 可能会导致接收方等待再次被调度）

想让用户态中断替代 Notification ，有如下的几个问题：

- 何时注册接收方？ 内核中的 notfication 结构会 bind 到某个 TCB （TCB 也会指向 notification 结构），可以在用户态执行 `seL4_TCB_BindNotification` 的时候默认将当前 TCB 作为用户态中断的接收方。
- 何时注册发送方？如果发送方与接收方共享 CSpace，就不需要获取 notification 的 cap ，否则需要通过 `seL4_CNode_Copy` 进行共享。一种可能的做法是让用户程序自行维护当前是否已经注册过发送方的信息，如果尚未注册则需要 Call 内核 service 来注册对应 notification 的发送方状态，否则就直接执行 `uipi.send` 。
- 完成注册后，发送方直接执行 uipi.send ，接收方则直接通过 uipi.read 读取位于 UINTC 中的 badge （Pending Requests），也就是说二者都不需要陷入就可以完成同步。
- 目前 Notification 机制并不支持用户态的异步，无法在改动特别小的情况下应用用户态中断处理函数，所以需要默认将 UINTC 中的 Active 位置 0 。

## 2023.07.13

尝试在已有的 Notification 逻辑中添加代码，目前遇到了几个问题：

- 何时注册接收方？没有绑定到 Ntfn 的其他 TCB 也可以通过 seL4_Wait 和 seL4_Poll 获取 badge ，按照现在的设计，仍需要额外的接口来注册成为接收方（**07.17 更新**：seL4 的逻辑是要么只有一个接收方绑定到 Notification ，要么多个接收方都不绑定）
- 何时注册发送方？通过 Copy 、Move 、Mint 等操作在发送方 CSpace 中加入 Ntfn 的 cap ，这些系统调用不会将 TCB 传给内核，`cap_cnode_cap` 类型的 cap 也无法得知其指向的 TCB ，因此无法通过这些系统调用注册发送方
- 如何获取发送方 index ？添加额外的接口：`void seL4_Uintr_Sender(CPtr_t recv, int *index)`
- 如何注册多个接收方？添加内核结构，包括接收 TCB 的等待队列，每个 TCB 保存对应的 UINTC index

## 2023.07.17

### seL4 uintr

修改代码内容如下（kernel）：

```log
 include/api/debug.h                                           |   5 +++
 include/arch/riscv/arch/64/mode/object/structures.bf          |  31 +++++++++++++++++++
 include/arch/riscv/arch/fastpath/fastpath.h                   |   7 +++++
 include/arch/riscv/arch/machine/registerset.h                 |   5 +++
 include/arch/riscv/arch/object/structures.h                   |  60 +++++++++++++++++++++++++++++++++++
 include/arch/riscv/arch/object/uintr.h                        | 146 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
 include/drivers/irq/riscv_uintc.h                             |  46 +++++++++++++++++++++++++++
 include/kernel/thread.h                                       |   6 ++++
 include/object/structures.h                                   |   3 ++
 include/object/tcb.h                                          |   7 +++++
 libsel4/arch_include/riscv/interfaces/sel4arch.xml            |  56 +++++++++++++++++++++++++++++++++
 libsel4/arch_include/riscv/sel4/arch/syscalls.h               |  53 +++++++++++++++++++++++++++++++
 libsel4/arch_include/riscv/sel4/arch/types.h                  |   4 ++-
 libsel4/sel4_arch_include/riscv64/sel4/sel4_arch/constants.h  |   4 +++
 libsel4/sel4_arch_include/riscv64/sel4/sel4_arch/objecttype.h |   3 ++
 libsel4/tools/syscall_stub_gen.py                             |   1 +
 src/api/syscall.c                                             |  19 ++++++++++++
 src/arch/riscv/c_traps.c                                      |   8 +++++
 src/arch/riscv/config.cmake                                   |   7 +++++
 src/arch/riscv/machine/capdl.c                                |   8 +++++
 src/arch/riscv/object/objecttype.c                            |  80 +++++++++++++++++++++++++++++++++++++++++++++--
 src/arch/riscv/object/uintr.c                                 | 144 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
 src/arch/riscv/traps.S                                        |  10 ++++++
 src/object/endpoint.c                                         |   2 +-
 src/object/objecttype.c                                       |   1 +
 src/object/tcb.c                                              |  77 +++++++++++++++++++++++++++++++++++++++++++++
 src/plat/qemu-riscv-virt/overlay-qemu-riscv-virt.dts          |   2 +-
 tools/hardware.yml                                            |   8 +++++
 28 files changed, 798 insertions(+), 5 deletions(-)
```

此外，在 `seL4_libs/libsel4vka/arch_include/riscv/vka/arch/object.h` 中进行了修改。

添加 seL4 API 如下：

- `seL4_UintrSend`：即 uipi.send 指令，利用 `seL4_RISCV_Uintr_RegisterSender` 返回的 index ，发送用户态中断
- `seL4_UintrNBRecv`：即 uipi.read 指令，读取当前 pending requests
- `seL4_Error seL4_TCB_BindUintr(seL4_TCB _service, seL4_CPtr uintr)`：绑定 TCB 和 uintr ，注册接收方 UINTC 表项
- `seL4_Error seL4_TCB_UnbindUintr(seL4_TCB _service)`：取消 TCB 和 uintr 绑定，释放占用的 UINTC 表项
- `seL4_RISCV_Uintr_RegisterSender_t seL4_RISCV_Uintr_RegisterSender(seL4_RISCV_Uintr _service)`：注册发送方并返回 index ，传入参数为发送方持有的接收方 uintr cap。

基础测例实现如下（与 Notification 进行对比）,可以看出 uintr 只多需要一次获取 index：

```c
static int sender_func(seL4_CPtr send_ntfn, seL4_CPtr recv_ntfn, seL4_Word send_badge, UNUSED seL4_Word arg)
{
    seL4_Word badge = 0, i;
    seL4_MessageInfo_t info = {{0}};
    for (i = 0; i < LOOP_TIMES; i++) {
        /* send a signal to receiver's notification */
        seL4_Signal(recv_ntfn);
        while (1) {
            /* poll on sender's notification */
            seL4_Poll(send_ntfn, &badge);
            if (badge == send_badge) break;
        }
    }
    return SUCCESS;
}

static int uintr_sender_func(seL4_CPtr recv_uintr, seL4_Word send_badge, UNUSED seL4_Word arg0, UNUSED seL4_Word arg1)
{
    seL4_Word badge = 0, i;
    seL4_MessageInfo_t info = {{0}};
    seL4_RISCV_Uintr_RegisterSender_t res;
    res = seL4_RISCV_Uintr_RegisterSender(recv_uintr);
    test_eq(res.error, 0);
    for (i = 0; i < LOOP_TIMES; i++) {
        /* send a signal to receiver's uintr */
        seL4_UintrSend(res.index);
        while (1) {
            /* poll on sender's uintr */
            seL4_UintrNBRecv(&badge);
            if (badge == 1 << send_badge) break;
        }
    }
    return SUCCESS;
}
```

添加内核结构和对应的 cap 如下：

```
block uintr_cap {
    field capUintrBadge         6
    field capUintrSendIndex     12
    field_high capUintrSendBase 39
    padding                     7

    field capType               5
    padding                     20
    field_high capUintrPtr      39
}

block uintr {
    padding                     7
    field state                 2
    field uintrIndex            16
    field_high uintrBoundTCB    39

    field uintrPending          64
}
```

注意在 badge 的语义上，目前的 uintr 计算方法是 `pending | (1 << badge) `，而 Notification 的计算方法是 `msgIdentifier | bdage` 。