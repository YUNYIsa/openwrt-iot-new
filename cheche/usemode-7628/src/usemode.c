#include <stdio.h>
#include <stdint.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#include <string.h>
#include <stdlib.h>
#include <errno.h>

typedef enum {
    IOT_DEV_MODE,     // 单网口模式 (UART2可用)
    IOT_GATEWAY_MODE  // 五网口模式 (UART2不可用)
} work_mode_7628_t;

static int debug_mode = 0;

#define DBG(fmt, ...) do { \
    if (debug_mode) fprintf(stderr, "[DEBUG] " fmt "\n", ##__VA_ARGS__); \
} while(0)

int set_7628_work_mode(work_mode_7628_t mode)
{
    int mem_fd;
    void *addr;
    uint32_t *reg;
    uint32_t old_val, new_val;

    if (geteuid() != 0) {
        fprintf(stderr, "Error: Must run as root!\n");
        return -1;
    }

    mem_fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (mem_fd == -1) {
        perror("open /dev/mem");
        return -1;
    }

    addr = mmap(NULL, 0x100, PROT_READ | PROT_WRITE, MAP_SHARED, mem_fd, 0x10000000);
    if (addr == MAP_FAILED) {
        perror("mmap 0x10000000");
        close(mem_fd);
        return -1;
    }

    reg = (uint32_t *)((char *)addr + 0x3c);
    old_val = *reg;

    DBG("Old register value at 0x1000003c: 0x%08x", old_val);

    if (mode == IOT_DEV_MODE) {
        *reg |= (0x0f << 17);
        new_val = *reg;
        printf("Set to IOT_DEV_MODE (single port)\n");
        DBG("New value: 0x%08x (bit17-20 set to 1111)", new_val);
    } else {
        *reg &= ~(0x0f << 17);
        new_val = *reg;
        printf("Set to IOT_GATEWAY_MODE (multi port)\n");
        DBG("New value: 0x%08x (bit17-20 cleared)", new_val);
    }

    if (new_val == old_val) {
        fprintf(stderr, "Warning: Register value unchanged! Hardware may not support or already set.\n");
    }

    close(mem_fd);
    munmap(addr, 0x100);
    return 0;
}

int main(int argc, char **argv)
{
    work_mode_7628_t mode = IOT_DEV_MODE;
    int i;

    // 检查环境变量debug
    if (getenv("USMODE_DEBUG")) {
        debug_mode = 1;
    }

    for (i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "--iot-mode")) {
            mode = IOT_DEV_MODE;
        } else if (!strcmp(argv[i], "--gateway-mode")) {
            mode = IOT_GATEWAY_MODE;
        } else if (!strcmp(argv[i], "--debug")) {
            debug_mode = 1;
        } else {
            printf("Usage: %s [--iot-mode | --gateway-mode] [--debug]\n", argv[0]);
            printf("  --debug: enable verbose logging\n");
            printf("  Without args: default to --iot-mode\n");
            return 1;
        }
    }

    DBG("Starting usemode (debug=%d)", debug_mode);
    return set_7628_work_mode(mode);
}
