#include <assert.h>
#include <elf.h>
#include <fcntl.h>
#include <memory.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>

#define DDR_TOTAL_SIZE 0x80000000
#define DDR_BASE_ADDR ((uintptr_t)0x100000000)

#define PL_RESETN_BASE_ADDR 0xFF0A0054

void *ddr_base;
uint32_t *resetn_base;
int fd;

void loader(char *imgfile, char *dtbfile, int offset)
{
    FILE *fp = fopen(imgfile, "rb");
    assert(fp);

    fseek(fp, 0, SEEK_END);
    long size = ftell(fp);
    printf("image size = %ld\n", size);

    fseek(fp, 0, SEEK_SET);
    size_t nr_read = fread(ddr_base + offset, size, 1, fp);
    printf("payload size %zd\n", nr_read);

    fclose(fp);

    fp = fopen(dtbfile, "rb");
    if (fp == NULL)
    {
        printf("No valid dtb file provided. Dtb in bootrom will be used.\n");
        return;
    }

    fseek(fp, 0, SEEK_END);
    size = ftell(fp);
    printf("dtb size = %ld\n", size);

    fseek(fp, 0, SEEK_SET);
    fread(ddr_base + offset + 0x8, size, 1, fp);

    fclose(fp);
}

void *create_map(size_t size, int fd, off_t offset)
{
    void *base = mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, offset);

    if (base == NULL)
    {
        perror("init_mem mmap failed:");
        close(fd);
        exit(1);
    }

    return base;
}

void init_map()
{
    fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (fd == -1)
    {
        perror("init_map open failed:");
        exit(1);
    }
    ddr_base = create_map(DDR_TOTAL_SIZE, fd, DDR_BASE_ADDR);
    resetn_base = create_map(4, fd, PL_RESETN_BASE_ADDR);
}

void resetn()
{
    resetn_base[0] = 0x00000000U;
    usleep(1);
    resetn_base[0] = 0x80000000U;
}

void finish_map()
{
    munmap((void *)ddr_base, DDR_TOTAL_SIZE);
    munmap((void *)resetn_base, 1);
    close(fd);
}

int main(int argc, char *argv[])
{
    /* map some devices into the address space of this program */
    init_map();

    printf("%s %s %s\n", argv[1], argv[2], argv[3]);
    loader(argv[1], argv[2], strtoll(argv[3], NULL, 16));

    /* reset RISC-V cores */
    resetn();

    finish_map();

    return 0;
}