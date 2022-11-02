`include "axi.vh"

module uintr_system_top (
    output [7:0] led
);

`axi_wire(AXI_MEM_MAPPED, 64, 1)
`axi_wire(AXI_MEM, 64, 1)
`axi_wire(AXI_MMIO, 64, 8)



endmodule