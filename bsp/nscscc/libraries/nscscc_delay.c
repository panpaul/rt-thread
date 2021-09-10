/*
 * Copyright (c) 2006-2018, RT-Thread Development Team
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 * Change Logs:
 * Date           Author       Notes
 * 2017-09-06     勤为本        first version
 * 2021-09-09     Paul         modified for NSCSCC
 */


#include "nscscc_clock.h"

void delay_ms(int j)
{
    int k_max = clk_get_cpu_rate()/1000/92; // TODO: experiment on 92
    int k = k_max;

    for ( ; j > 0; j--)
    {
        for (k = k_max; k > 0; k--)
        {
            __asm__ ("nop");
        }
    }

    return ;
}

void delay_s(int i)
{
    for ( ; i > 0; i--)
    {
        delay_ms(1000);
    }

    return ;
}



