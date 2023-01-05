# Graduation Journal

## 11.24

- 阅读论文 [CHERI](https://ieeexplore.ieee.org/document/7163016)
- 目前的问题还是 Rocket 上板后无法与 DDR 进行交互，和尤予阳学长一起尝试用 System ILA 抓取信号，但是没有看到有效信息；labeled RISC-V 和 zynq-fpga 项目均采用直连的办法是可以正常访问的，所以怀疑问题出在对 Rocket 的改动和配置上
- **OS classroom**：
  - 参考 `npucore` 和 `maturin`，重新设计实现了一个可以在 no_std 下使用的 `VFS` 模块，这个模块内定义了 `trait File` 用于文件抽象，`trait VFS` 用于文件系统抽象（例如 `easy-fs` 和 `rust-fatfs` 都可以通过实现同一个接口来接入系统），`struct Path` 对路径作了一层封装，解决了 `.` 和 `..` 路径处理起来比较麻烦的问题，具体代码在 [tCore](https://github.com/tkf2019/tCore/tree/main/crates/tvfs/src) 。
  - 完成 Block Cache 相关模块设计，并成功将 rust-fatfs 接入 kernel（`maturin` 的办法是修改了 `rust-fatfs` 对 `fscommon`, core2 等项目的依赖，我觉得扩展起来比较困难，且 `BufStream` 读写磁盘开销比较大，所以我只引入了`rust-fatfs` ）。具体代码在 [tCore](https://github.com/tkf2019/tCore/blob/main/kernel/src/fs/fat/mod.rs)。
  - 遇到一个有关 Rust 语言的问题： `match` 闭包不会根据最外层函数返回值的类型进行推导，例如如下写法会报错，经过和闭浩扬的讨论，发现在这种两层以上闭包推导时，`match` 只能根据内部分支闭包返回值的覆盖情况推导，所以需要用一个局部变量强行指定动态推导的类型来通过编译（这个我自己盯着看了一下午也没有想出来到底是怎么回事）

```rust
fn open(&self, path: &str, flags: OpenFlags) -> Result<Arc<dyn File>, ErrNO> {
    root.open_dir(path).and_then(|dir| match {
        ... // Some branches
    })
}
// It works
fn open(&self, path: &str, flags: OpenFlags) -> Result<Arc<dyn File>, ErrNO> {
    root.open_dir(path).and_then(|dir| {
        let result: Result<Arc<dyn File>, ErrNO> = match {
        ... // Some branches
        };
        result
    })
}
```

## 12.01

- 由于疫情原因，远程调试硬件不太方便，而且对 RISC-V 用户态中断扩展的设计尚未完善，和老师讨论后，决定在 QEMU 上进行实践，并将此作为毕设内容
- **OS classroom**：

  - 关闭 log 之后会出现 qemu 执行卡住的情况，用 gdb 调试发现 kernel 执行到这里时 trap 了：

    ```asm
    8020a6b8: 85 48         li a7, 1
    8020a6ba: 03 c5 05 00   lbu a0, 0(a1)
    8020a6be: 73 00 00 00   ecall 
    ```

    这里 a1 从一个合法的物理地址变成了 1，应该是 SBI 有问题，我之前从某个地方拷贝了一个 `rustsbi.bin` 的镜像，换成 qemu default bios 就可以正常运行了。

  - 发现内核启动后有时会卡住，上 gdb 调试看不出来，实现了 kernel trap，随机触发 Page Fault，猜测是没有刷新内存中的页表，里面有随机初始化的值，rCore-tutorial 好像并没有处理这个问题。
  - 之前没有认真了解过 ELF，因为要运行 libc、busybox 测例，涉及到动态链接，所以借着这个机会把相关文档看了一下。
  - 参考 `maturin` 实现了一个 `oscomp` 模块，用来加载测例，更新并打印测试结果。
  - 将内核改为了 SMP 版本，因为之后要实现用户态中断，所以直接实现多核版本；Rust 鼓励并发，支持通过`Arc<>`、`Mutex<>`等类型将对象进行细粒度的封装，很多全局静态变量例如`Lazy<>`也要求内部结构实现`Send`和`Sync`。如果想先跑通单核版本，用`Rc<>`和`RefCell<>`，之后重构起来会非常麻烦，不如一开始实现的过程中就把问题想清楚。
- 下周继续写 os，其他时间看看 qemu，打算先把 x86 的修改复现一下。

## 12.08

- 本周主要要在处理返乡的事情，所以进展不是很多。
- 参考 qemu 上关于 intel 用户态中断设计的改动，阅读 qemu 源码。
- **OS classroom**:
  - 参考 Linux 源码，将 Linux 时间子系统简单抽象为一个子集，代码整理在一个 timer crate 中。
  - 完善 kernel 的虚存管理部分，增加延时分配的物理页帧，涉及到 COW 等机制的实现。（感觉 maturin 这部分抽象的特别好，所以参考着实现了一版，目前是以 module 的形式实现在 kernel 内部的，之后可以考虑抽象成单独的 crate）
  - 本地通过部分 libc 静态测例。
- 下周计划通过 libc 全部测例，开始着手修改 qmeu riscv 部分。

## 12.15

- 阅读 QEMU 源码：
  - 复现 xcd 的工作
  - 之前 hkp 学长已经有 RISC-N 在 QEMU 5 上的实现了，参考仓库中的 commit ，将改动移到了 QEMU 7 上
- **OS classroom**
  - 添加更多系统调用，重点完善 `sys_mmap`，`sys_munmap` 和 `sys_brk` 。`sys_mmap` 参考了 `maturin`，目前还没有处理 `MAP_SHARED` 和 `MAP_PRIVATE`；`sys_munmap` 和 `sys_brk` 参考了 Linux 内核实现。
  - 随机调换测例顺序或者测例数量，出现如下现象中的任意一种：
    - 卡在用户态的某个循环里
    - 用户态 exit code 是一个奇怪的值
    - 用户态访问非法地址
  - 和 bhy 讨论，总结此类问题可能出现的原因大致分为几类：用户程序初始化的时候丢失信息、中断、刷新页表后没有刷新 TLB，仔细检查之后，发现并不是这些问题中的任何一种。目前 `FixedPMA` 是初始化即分配物理页帧，对连续的 `AllocatedFrameRange` 进行再封装，这个页帧管理结构主要用于用户程序初始化，情况大致分为以下几种：
    - 根据 ELF 初始化代码段和数据段
    - 初始化用户栈
    - 调用 `kstack_alloc` 初始化内核栈
    - 初始化 `TrapFrame`
  - 用户程序会访问到这些地址（主要是 .bss 段），拿到了没有置为 0 的值，然后就出现了奇怪的行为。所以在分配新物理页帧时应先手动清零，再将程序的数据拷贝过来。
- 下周计划：先确保修改后 RISC-V N 能工作，进一步了解 AIA、PLIC 等。

## 12.29

- 了解 QEMU aclint 工作原理，见 [qemu-journal](./qemu-journal.md)
- 写 RISC-V uintr specification，见 [spec](./spec.md)
- 下周计划：整理当前工作，完善 ppt 并准备开题报告

## 1.5

- 对 QEMU 进行代码分析，完善设计思路，更新 ppt
- **OS classroom**: 
  - 完成了一部分信号机制的代码，主要位于模块 tsignal 中，参考了 maturin 和 Linux 内核实现
  - 加入了 uintr 模块对 qemu 加入的指令进行测试
