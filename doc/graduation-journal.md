# 11.24

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