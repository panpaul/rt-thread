/*
 * Copyright (c) 2006-2018, RT-Thread Development Team
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 * Change Logs:
 * Date           Author       Notes
 * 2018-05-08     zhuangwei    the first version
 * 2021-09-09     Paul         modified for NSCSCC
 */
#include <rtthread.h>
#include <rtdevice.h>
#include <rthw.h>
#include "drv_uart.h"
#include "nscscc_uart.h"
#include "nscscc_regs.h"

static rt_err_t nscscc_uart_configure(struct rt_serial_device *serial, struct serial_configure *cfg)
{
    RT_ASSERT(serial != RT_NULL);
    RT_ASSERT(cfg != RT_NULL);

    uart_init();

    return RT_EOK;
}

static rt_err_t nscscc_uart_control(struct rt_serial_device *serial, int cmd, void *arg)
{
    RT_ASSERT(serial != RT_NULL);

    switch (cmd)
    {
    case RT_DEVICE_CTRL_CLR_INT: /* disable rx irq */
        rt_hw_interrupt_mask(3);
        break;

    case RT_DEVICE_CTRL_SET_INT: /* enable rx irq */
        rt_hw_interrupt_umask(3);
        break;

    default:
        break;
    }

    return RT_EOK;
}

static int nscscc_uart_putc(struct rt_serial_device *serial, char c)
{
    RT_ASSERT(serial != RT_NULL);

    uart_putc(c);

    return 1;
}

static int nscscc_uart_getc(struct rt_serial_device *serial)
{
    RT_ASSERT(serial != RT_NULL);

    void *uart_base = (uint32_t*)NSCSCC_UART00_BASE;

    if (LSR_RXRDY & reg_read_8(uart_base + NSCSCC_UART_LSR_OFFSET))
    {
        return reg_read_8(uart_base + NSCSCC_UART_DAT_OFFSET);
    }

    return -1;
}

/* UART interrupt handler */
static void uart_irq_handler(int vector, void *param)
{
    struct rt_serial_device *serial = (struct rt_serial_device *)param;
    
    RT_ASSERT(serial != RT_NULL);

    void *uart_base = (uint32_t*)NSCSCC_UART00_BASE;
    unsigned char iir = reg_read_8(uart_base + NSCSCC_UART_IIR_OFFSET);

    // 判断是否为接收超时或接收到有效数据
    if ((IIR_RXTOUT & iir) || (IIR_RXRDY & iir))
    {
        rt_interrupt_enter();
        rt_hw_serial_isr(serial, RT_SERIAL_EVENT_RX_IND);
        rt_interrupt_leave();
    }

}

static const struct rt_uart_ops ls1c_uart_ops =
{
    nscscc_uart_configure,
    nscscc_uart_control,
    nscscc_uart_putc,
    nscscc_uart_getc,
};

void rt_hw_uart_init(void)
{
}

