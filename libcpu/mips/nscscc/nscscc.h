/*
 * Misc define for NSCSCC
 *
 * Copyright (c) 2006-2021, RT-Thread Development Team
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 * Change Logs:
 * Date           Author       Notes
 * 2019-12-04     Jiaxun Yang  Initial version
 * 2021-09-09     Paul         Modified for NSCSCC
 */

#ifndef __NSCSCC_H__
#define __NSCSCC_H__

#include <mips.h>

#define NSCSCC_NR_IRQS      7

#define NSCSCC_MAC0_IRQ     2
#define NSCSCC_UART0_IRQ    3
#define NSCSCC_SPI0_IRQ     4
#define NSCSCC_NAND_IRQ     5
#define NSCSCC_DMA_IRQ      6

extern void rt_hw_timer_init(void);

#endif
