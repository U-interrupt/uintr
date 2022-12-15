# RISC-V User-interrupt Specification

## RISC-V AIA

有关 MSI (Message Signalled Interrupts):

- 传统发中断 pin-based out-of-band ：外设有单独引脚，独立于数据总线
- MSI：处理器和外设之间存在中断控制器，外设通过数据总线给控制器发送更丰富的中断信息，控制器进行处理后再发给处理器，这些信息可以帮助外设和控制器更好地决策发送中断的时机、目标等。
- 可以增加中断数量
- pin-based interrupt 和 posted-write 之间的竞争问题：PCI 内存控制器可能会推迟写入 DMA，导致处理器收到中断后立即尝试通过 DMA 读取旧的数据，所以中断控制器需要读取 PCI 内存控制器来判读写入是否完成。MSI write 和 DMA write 之间共用总线，所以不会出现这种异步的竞争问题。

AIA 的设计目标：

- 支持 MSI，支持 PCIe 和其他设备
- 定义 APLIC （Advanced PLIC），每个特权级都有独立的 control plane 将 wired interrupt 转换为 MSI
