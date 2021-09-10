/*
 * Copyright (c) 2006-2021, RT-Thread Development Team
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 * Change Logs:
 * Date                Author         Notes
 * 2010-07-09     Bernard        first version
 * 2010-09-11     Bernard        add CPU reset implementation
 * 2015-07-06     chinesebear    modified for loongson 1c
 * 2021-09-09     Paul           modified for NSCSCC
 */

#include <rtthread.h>
#include "nscscc.h"

/**
 * @addtogroup NSCSCC
 */

/*@{*/

/**
 * this function will reset CPU
 *
 */
RT_WEAK void rt_hw_cpu_reset(void)
{
    rt_kprintf("This core doesn't support reset...\n");
    while (1);
}

/**
 * this function will shutdown CPU
 *
 */
RT_WEAK void rt_hw_cpu_shutdown(void)
{
    rt_kprintf("This core doesn't support shutdown...\n");
    while (1);
}


#define Hit_Invalidate_I    0x10
#define Hit_Invalidate_D    0x11
#define CONFIG_SYS_ICACHELINE_SIZE   32
#define CONFIG_SYS_DCACHELINE_SIZE   16
#define Hit_Writeback_Inv_D 0x15


void flush_cache(unsigned long start_addr, unsigned long size)
{
    unsigned long ilsize = CONFIG_SYS_ICACHELINE_SIZE;
    unsigned long dlsize = CONFIG_SYS_DCACHELINE_SIZE;
    unsigned long iaddr  = start_addr & ~(ilsize - 1);
    unsigned long daddr  = start_addr & ~(dlsize - 1);
    unsigned long iaend  = (start_addr + size - 1) & ~(ilsize - 1);
    unsigned long daend  = (start_addr + size - 1) & ~(dlsize - 1);

    while (1) {
        cache_op(Hit_Writeback_Inv_D, daddr);
        if (daddr >= daend)
            break;
        daddr += dlsize;
    }

    while (1) {
        cache_op(Hit_Invalidate_I, iaddr);
        if (iaddr >= iaend)
            break;
        iaddr += ilsize;
    }
}


/*@}*/

