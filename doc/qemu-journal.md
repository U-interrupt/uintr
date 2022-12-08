# QEMU

参考在 i386 下的改动，发现主要修改的部分位于 target/riscv 。

QEMU RISC-V 的实现架构和 x86 的有很大不同。

主要关注几个方面：

- 新指令
- CSR 相关操作
- 核间中断

中断异常、CSR、CSR bits 等定义位于 cpu_bits.h 。

CSR 的修改主要位于 csr.c 。

```c
riscv_csr_operations csr_ops[CSR_TABLE_SIZE];

typedef struct {
    const char *name;
    riscv_csr_predicate_fn predicate;
    riscv_csr_read_fn read;
    riscv_csr_write_fn write;
    riscv_csr_op_fn op;
    riscv_csr_read128_fn read128;
    riscv_csr_write128_fn write128;
} riscv_csr_operations;
```

这个结构体给出了针对 CSR 寄存器进行的操作。
