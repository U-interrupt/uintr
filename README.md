# U-interrupt

This is a zcu102 port for the implementation of RISC-V user interrupt extension, based on [Rocket](https://github.com/chipsalliance/rocket-chip).

## Table of contents

- What is user interrupt?
- System stack of Zynq FPGA, going top-down from RISC-V software to hardware layouts.
- Modifications to Rocket Chip to support user interrupt.
- Modifications to rCore to take advantage of new hardware features.
- Modifications to Linux for further design and evaluation.

## Plans

- Get familiar with the process of hardware development on zcu102.
  - Port Rocket Chip to zcu102.
  - Boot rCore and Linux on Rocket Chip.
- Apply user-interrupt hardware design to Rocket. 
