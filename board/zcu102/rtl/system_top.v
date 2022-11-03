`include "axi.vh"

module uintr_system_top (
    output [7:0] led
);

`axi_wire(AXI_MEM_MAPPED, 64, 4)
`axi_wire(AXI_MEM, 64, 4);
`axi_wire(AXI_MMIO, 64, 4);
`axi_wire(AXI_DMA, 64, 2);

wire core_clk, core_rstn;
wire mm2s_introut, s2mm_introut;
wire [4:0] core_uart_irq;

soc zynq_soc0 (
    `axi_connect_if(S_AXI_MEM, AXI_MEM_MAPPED),
    `axi_connect_if(S_AXI_MMIO, AXI_MMIO),
    `axi_connect_if(M_AXI_DMA, AXI_DMA),

    .mm2s_introut       (mm2s_introut),
    .s2mm_introut       (s2mm_introut),

    .core_clk           (core_clk),
    .core_rstn          (core_rstn),
    .core_uart_irq      (core_uart_irq)
);



endmodule