# RISC-V User-interrupt Specification

> Version: 0.1.1
> Date: 2023.02.19

## Introduction

One of the most impressive characteristic of RISC-V is that it uses a simple load-store architecture. So we proposed a new instruction `UIPI(User Inter-Processor Interrupt)` and a new external device `UINTC (User-Interrupt Controller)` to reduce modifications on hardware for further implementation and evaluation on Rocket Chip and possible optimizations on memory architecture.

We try to prevent following situations when a user can send IPI without trapped into kernel:

1. Malicious sender tries to send an unregistered user interrupt to other harts.
2. Malicious receiver tries to modify the hartid to redirect a user interrupt to other harts.
3. The receiver is not running on the target hart and an invalid user interrupt is sent to the hart.


## User Interrupt Configuration (suicfg)

The **suicfg** is an SXLEN-bit read/write register, which indicates the base address of UINTC. 

## User Interrupt Sender Table (suist)

The **suist** is an SXLEN-bit read/write register, formatted as below:

User interrupt sender table **suist** when `SXLEN=32`:

```txt
+------------+--------------+----------+----------+
| Enable (1) | Reserved (1) | Size (8) | PPN (22) |
+------------+--------------+----------+----------+
```

User interrupt sender table **suist** when `SXLEN=64`:

```txt
+------------+--------------+-----------+----------+
| Enable (1) | Reserved (7) | Size (12) | PPN (44) |
+------------+--------------+-----------+----------+
```

This register holds the physical page number (PPN) of the first page of sender status; the **Size** field, which limits the number of pages of uist; the **Enable** field, which indicates user-interrupt posting is enabled for current user.

This register cannot be accessed directly in user privilege.

A user interrupt sender table might take up several pages in memory, each entry formatted as below:

|  Bit Position(s) | Name | Description |
|  ----  | ----  | ---- |
| 0 | Valid | If this bit is set, the entry is valid. |
| 15:1 | Reserved | User interrupt delivery ignores these bits. |
| 31:16 | Sender Vector | A vector registered by sender. |
| 47:32 | Reserved | User interrupt delivery ignores these bits. |
| 63:48 | UIRS index | User receiver status index in UINTC. |

## User Interrupt Receiver Status (suirs)

The **suirs** is an SXLEN-bit read/write register, formatted as below:

User interrupt receiver status **suirs** when `SXLEN=32`:

```txt
+------------+---------------+------------+
| Enable (1) | Reserved (15) | index (16) |
+------------+---------------+------------+
```

User interrupt receiver status **suirs** when `SXLEN=64`:

```txt
+------------+---------------+------------+
| Enable (1) | Reserved (47) | index (16) |
+------------+---------------+------------+
```

This register cannot be accessed directly in user privilege.

This register holds the `index` corresponding to a valid entry in UINTC, formatted as below:

UINTC receiver status entry when `SXLEN=32`:

|  Bit Position(s) | Name | Description |
|  ----  | ----  | ---- |
| 0  | Active | If this bit is **not** set, no interrupt will be delivered for this target. |
| 1 | Mode | **0x0**: 32 bit mode |
| 15:2  | Reserved | User interrupt processing ignores these bits. |
| 31:16 | Hartid | The integer ID of the hardware thread running the code. |
| 63:32 | Pending Requests | One bit for each user interrupt vector. There is user-interrupt request for a vector if the corresponding bit is 1. |
| 127:64 | Reserved | User interrupt processing ignores these bits. |

UINTC receiver status entry when `SXLEN=64`:

|  Bit Position(s) | Name | Description |
|  ----  | ----  | ---- |
| 0  | Active | If this bit is **not** set, no interrupt will be delivered for this target. |
| 1  | Mode | **0x1**: 64 bit mode |
| 15:2  | Reserved | User interrupt processing ignores these bits. |
| 31:16 | Hartid | The integer ID of the hardware thread running the code. |
| 63:32 | Reserved | User interrupt processing ignores these bits. |
| 127:64 | Pending Requests | One bit for each user interrupt vector. There is user-interrupt request for a vector if the corresponding bit is 1. |

## UIPI

UIPI is an I-type instruction formatted as below:

```txt
 31        20 19   15 14   12 11   7 6        0 
+-------------+-------+-----+------+---------+
| uipi opcode |  rs1  | 010 |  rd  | 1111011 | UIPI I-type
+-------------+-------+-----+------+---------+
```

The **uipi opcode** field, which indicates the opration processed by this instruction:

|  uipi opcode   | op |
|  ----  | ----  |
| 0x0 | SEND |
| 0x1 | READ |
| 0x2 | WRITE |
| 0x3 | ACTIVATE |
| 0x4 | DEACTIVATE |

For Sender:

An instruction `uipi SEND, <index>` is used for sending a user interrupt. As described in **suist**, the `index` parameter is used to locate the target sender status entry with **PPN** field in **suist** to get detailed information about the receiver:

`physical address = ( PPN << 0xC ) + (index * sizeof(uiste))`

Currently, a user interrupt sender table entry is **128 B** in size. Reserved bits in **suist** might be used for further configurations.

If `uipi SEND, <index>` is executed wit   h an index exceeding **Size** field in **suist**, or the target entry is not valid, this instruction will have no effect; neither interrupt nor memory access will be processed.

For Receiver:

An instruction `uipi READ, <reg>`(`uipi WRITE, <reg>`) is used to read pending bits from (write to) UINTC with the index in **suirs**. **rs1** filed is wired to zero for `READ`, while **rd** field is wired to zero for `WRITE`.

An instruction `uipi ACTIVATE` or `uipi DEACTIVATE` is used to set or unset the **Active** field in the entry with the index in **suirs**.

Thus the **Hartid** and **Mode** field in UIRS cannot be modified by user.

## UINTC

A external device manages user interrupt, holding a user interrupt receiver table.

The maximum number of **Receivers** supported by a single UINTC device is **512**.

UINTC Register Map:

| Offset |  Width | Attr | Name | Description |
|  ----  | ----  |  ----  | ----  |  ----  |
| 0x0000_0000 | 32B | RW | UIRS0 | Index 0 User Interrupt Receiver Status |
| 0x0000_0040 | 32B | RW | UIRS1 | Index 1 User Interrupt Receiver Status |
| ... | ... | ... | ... | ... |
| 0x0000_3FC0 | 32B | RW | UIRS511 | Index 511 User Interrupt Receiver Status |

A **32 B** register is divided into **4** operations corresponding to the **uipi opcode** field specification of `UIPI`. Operations are aligned to **8 B** for direct load and store in S mode.

|  Offset   | OP(R) | OP(W) |
|  ----  | ----  | ---- |
| 0x00 | Reserved | SEND |
| 0x08 | READ_LOW | WRITE_LOW |
| 0x10 | READ_HIGH | WRITE_HIGH |
| 0x18 | GET_ACTIVE | SET_ACTIVE |

- SEND: See `uipi SEND`. **Sender Vector** will be posted with a writing request. An invalid value out of bound will be ignored.
- READ_HIGH and WRITE_HIGH: See `uipi READ` and `uipi WRITE`.
- READ_LOW and WRITE_LOW: Sets **Hartid**; sets **Mode**; activates user interrupt.
- GET_ACTIVE and SET_ACTIVE: See `uipi ACTIVATE`.

## API

Currently, we use the same syscalls as proposed by [x86 User Interrupts Support](https://lwn.net/Articles/869140/):

1. A receiver can register/unregister an interrupt handler using the uintr receiver related syscalls: `uintr_register_handler(handler, flags)` and `uintr_unregister_handler(flags)`.
2. A syscall also allows a receiver to register a vector and create a user interrupt file descriptor - uintr_fd: `uintr_create_fd(vector, flags, &uintr_fd)`.
3. Any sender with access to uintr_fd can use it to deliver user interrupts: `uintr_register_sender(uintr_fd, flags, &uist_index)`.
4. A receiver can yield with `uintr_wait()` to wait for a user insterrupt and be scheduled later by special mechanisms.

The whole process can be described as below:

1. A receiver registers a handler and gets a file descriptor. Virtual address of the handler will be written to `utvec`.
2. A sender registers a vector with a file descriptor shared by the receiver. A new User Interrupt Sender Table (UIST) will be allocated by supervisor if not exists. The index of User Interrupt Receiver Status in UINTC will be written to the entry of UIST. The sender then gets an index corresponding to a valid entry of UIST.
3. The sender uses the index to execute a `uipi SEND, <index>`. The CPU just does something like address translation:
   1. CPU will read from memory to find the entry of UIST.
   2. A writing request like `sd 0x1, SEND(base)` will be posted to UINTC.
   3. UINTC writes the corresponding bit in the **Pending Requests** field.
   4. External interrupt will be delivered to the target hart if **Active** field is set to 0x1.
4. With User software interrupt delegated to User and `uie.USIE & uip.USIP & ustatus.UIE == 1`, the receiver will jump to `utvec` to handle the interrupt immediately if it is running on the target hart. Just like trap and interrupt handled in S mode, a `uret` will help get back to normal execution with saved `pc` in `uepc`.

If the receiver is **not** running, **Active** field will be cleared in higher privilege mode and an external interrupt will not be delivered by UINTC. Before a `sret` or `mret`, we can set `uip.USIP` manually. When the privilege mode is set back to U, an interrupt will be recognized just like step 4 above.

In higher privilege mode, we can do all the things described above just through `ld` and `sd` with previously mapped device address.
