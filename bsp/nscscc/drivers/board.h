/*
 * Copyright (c) 2006-2018, RT-Thread Development Team
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 * Change Logs:
 * Date                Author         Notes
 * 2010-06-25     Bernard       first version
 * 2011-08-08     lgnq          modified for Loongson LS1B
 * 2015-07-06     chinesebear   modified for Loongson LS1C
 * 2019-12-04     Jiaxun Yang   Add board config defines
 * 2021-09-09     Paul          modified for NSCSCC
 */

#ifndef __BOARD_H__
#define __BOARD_H__
#include <rtconfig.h>

#ifndef __ASSEMBLY__
void rt_hw_board_init(void);
#endif

#define CPU_HZ    (33 * 1000000)
#define MEM_SIZE  (0x7ffffff)

#endif
