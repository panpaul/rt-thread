/*
 * Copyright (c) 2006-2018, RT-Thread Development Team
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 * Change Logs:
 * Date           Author       Notes
 * 2017-09-06     勤为本       first version
 * 2021-09-09     Paul        modified for NSCSCC
 */


#include "nscscc_public.h"

unsigned long clk_get_cpu_rate(void)
{
    return 33 * 1000000;
}
