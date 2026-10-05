/*
 * Copyright (c) 2022 Nordic Semiconductor
 * Copyright (c) 2026 Sharukh Hasan
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 * After Zephyr's samples/sysbuild/with_mcuboot.
 */

#include <zephyr/kernel.h>
#include <zephyr/linker/linker-defs.h>

int main(void)
{
	printk("Address of image %p\n", (void *)__rom_region_start);
	printk("rollcall example on %s\n", CONFIG_BOARD);
	return 0;
}
