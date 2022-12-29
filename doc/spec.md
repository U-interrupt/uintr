# RISC-V User-interrupt Specification

## CSRs

### Supervisor User Interrupt Target Table (suitt) Register

The **suitt** is an 64-bit read/write register, formatted as below:

```txt
+------------+--------------+-------------+----------+
| ENABLE (1) | Reserved (7) | UITTSZ (12) | PPN (44) |
+------------+--------------+-------------+----------+
```

This register holds the physical page number (PPN) of the first page of user interrupt target table (UITT); the UITTSZ field, which limits the pages of UITT; the ENABLE field, which indicates user-interrupt posting is enabled for current user.

### User Posted Interrupt Descriptor Address (upidaddr) Register

The **upidaddr** is an 64-bit read/write register which holds the virtual address of UPID.

## Instructions

### SENDUIPI

A new instruction `senduipi <index>` is used for sending a user interrupt. As described in **suitt**, the `index` parameter is used to locate the target user interrupt target table entry (UITTE) with PPN field in **suitt** to get detailed information about the receiver:

`UITTE physical address = ( PPN << 0xC ) + (index * UITTE size)`

Currently, a user interrupt target table entry is **128 B** in size. Reserved bits in **suitt** might be used for further configurations.

If `senduipi <index>` is used with an index exceeding UITTSZ field in **suitt**, the entire instruction has no effect; neither interrupt nor memory access will be processed.

SENDUIPI is an I-type instruction formatted as below:

```txt
                                     opcode
+------------+-------+-----+-------+---------+
| index (12) | 00000 | 000 | 00000 | 1110100 | SENDUIPI
+------------+-------+-----+-------+---------+
```

### URET

> From riscv-privileged-v1.10:
> The MRET, SRET, or URET instructions are used to return from traps in M-mode, S-mode, or U-mode respectively. When executing an xRET instruction, supposing xPP holds the value y, xIE is set to xPIE; the privilege mode is changed to y; xPIE is set to 1; and xPP is set to U (or M if user-mode is not supported).
