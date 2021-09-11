/*
 * File      : board.c
 * This file is part of RT-Thread RTOS
 * COPYRIGHT (C) 2006-2012, RT-Thread Develop Team
 *
 * The license and distribution terms for this file may be
 * found in the file LICENSE in this distribution or at
 * http://www.rt-thread.org/license/LICENSE
 *
 * Change Logs:
 * Date           Author       Notes
 * 2011-08-08     lgnq         first version
 * 2021-09-10     Paul         modified for NSCSCC
 */

#include <rthw.h>
#include <rtthread.h>
#include <ipc/ringbuffer.h>

#include "nscscc.h"
#include "selfboot.h" // contains FIFO macro
#include "uart.h"

#if defined(RT_USING_DEVICE)

#define UART_RX_MAX_SZ 512
rt_uint8_t rx_buffer[UART_RX_MAX_SZ];

struct rt_uart_nscscc
{
    struct rt_device parent;
    rt_uint32_t hw_base;
    rt_uint32_t irq;
    struct rt_ringbuffer rx_rb;
} uart_device;

static void rt_uart_irqhandler(int irqno, void *param)
{
    rt_ubase_t level;
    rt_uint8_t isr;
    struct rt_uart_nscscc *uart = &uart_device;

    level = rt_hw_interrupt_disable();

    /* read interrupt status and clear it */
    isr = UART_IIR(uart->hw_base);
    isr = (isr >> 1) & 0x3;

    /* receive data available */
    if (isr & 0x02)
    {
        /* Receive Data Available */
        while (UART_LSR(uart->hw_base) & UARTLSR_DR)
            rt_ringbuffer_putchar_force(&(uart->rx_rb), (rt_uint8_t)UART_DAT(uart->hw_base));

        rt_hw_interrupt_enable(level);

        /* invoke callback */
        if (uart->parent.rx_indicate != RT_NULL)
            uart->parent.rx_indicate(&uart->parent, rt_ringbuffer_data_len(&uart->rx_rb));
    }
    else
        rt_hw_interrupt_enable(level);

    return;
}

static rt_err_t rt_uart_init(rt_device_t dev)
{
    rt_uint32_t baud_div;
    struct rt_uart_nscscc *uart = (struct rt_uart_nscscc *)dev;

    RT_ASSERT(uart != RT_NULL);

    /* init UART Hardware */
    UART_IER(uart->hw_base) = 0;                           /* clear interrupt */
    UART_FCR(uart->hw_base) = FIFO_RCV_RST | FIFO_XMT_RST; /* reset UART Rx/Tx */

    /* enable UART clock */
    /* set databits, stopbits and parity. (8-bit data, 1 stopbit, no parity) */
    UART_LCR(uart->hw_base) = CFCR_8BITS;

    /* set baudrate */
    baud_div = 0x23;
    UART_LCR(uart->hw_base) |= UARTLCR_DLAB;

    UART_MSB(uart->hw_base) = (baud_div >> 8) & 0xff;
    UART_LSB(uart->hw_base) = baud_div & 0xff;

    UART_LCR(uart->hw_base) &= ~UARTLCR_DLAB;

    /* DTR RTS */
    UART_MCR(uart->hw_base) = MCR_DTR | MCR_RTS;

    /* Enable UART unit, enable and clear FIFO */
    UART_FCR(uart->hw_base) = FIFO_ENABLE | FIFO_RCV_RST | FIFO_XMT_RST | FIFO_TRIGGER_4;

    return RT_EOK;
}

static rt_err_t rt_uart_open(rt_device_t dev, rt_uint16_t oflag)
{
    struct rt_uart_nscscc *uart = (struct rt_uart_nscscc *)dev;

    RT_ASSERT(uart != RT_NULL);
    if (dev->flag & RT_DEVICE_FLAG_INT_RX)
    {
        /* Enable the UART Interrupt */
        UART_IER(uart->hw_base) |= UARTIER_IRXE;

        /* install interrupt */
        rt_hw_interrupt_install(uart->irq, rt_uart_irqhandler, RT_NULL, "UART");
        rt_hw_interrupt_umask(uart->irq);
    }

    return RT_EOK;
}

static rt_err_t rt_uart_close(rt_device_t dev)
{
    struct rt_uart_nscscc *uart = (struct rt_uart_nscscc *)dev;

    RT_ASSERT(uart != RT_NULL);
    if (dev->flag & RT_DEVICE_FLAG_INT_RX)
    {
        /* Disable the UART Interrupt */
        UART_IER(uart->hw_base) &= ~(UARTIER_IRXE);
    }

    return RT_EOK;
}

static rt_size_t rt_uart_read(rt_device_t dev, rt_off_t pos, void *buffer, rt_size_t size)
{
    rt_size_t length;
    struct rt_uart_nscscc *uart = (struct rt_uart_nscscc *)dev;

    RT_ASSERT(uart != RT_NULL);

    /* point to buffer */
    if (dev->flag & RT_DEVICE_FLAG_INT_RX)
    {
        rt_base_t level;
        level = rt_hw_interrupt_disable();

        length = rt_ringbuffer_get(&(uart->rx_rb), buffer, size);

        rt_hw_interrupt_enable(level);

        return length;
    }

    return 0;
}

static rt_size_t rt_uart_write(rt_device_t dev, rt_off_t pos, const void *buffer, rt_size_t size)
{
    char *ptr;
    struct rt_uart_nscscc *uart = (struct rt_uart_nscscc *)dev;

    RT_ASSERT(uart != RT_NULL);

    ptr = (char *)buffer;

    if (dev->flag & RT_DEVICE_FLAG_STREAM)
    {
        /* stream mode */
        while (size)
        {
            if (*ptr == '\n')
            {
                /* FIFO status, contain valid data */
                while (!(UART_LSR(uart->hw_base) & (UARTLSR_TE | UARTLSR_TFE)))
                    ;
                /* write data */
                UART_DAT(uart->hw_base) = '\r';
            }

            /* FIFO status, contain valid data */
            while (!(UART_LSR(uart->hw_base) & (UARTLSR_TE | UARTLSR_TFE)))
                ;
            /* write data */
            UART_DAT(uart->hw_base) = *ptr;

            ptr++;
            size--;
        }
    }
    else
    {
        while (size != 0)
        {
            /* FIFO status, contain valid data */
            while (!(UART_LSR(uart->hw_base) & (UARTLSR_TE | UARTLSR_TFE)))
                ;

            /* write data */
            UART_DAT(uart->hw_base) = *ptr;

            ptr++;
            size--;
        }
    }

    return (rt_size_t)ptr - (rt_size_t)buffer;
}

void rt_hw_uart_init(void)
{
    struct rt_uart_nscscc *uart;

    /* get uart device */
    uart = &uart_device;

    /* device initialization */
    uart->parent.type = RT_Device_Class_Char;

    rt_ringbuffer_init(&(uart->rx_rb), rx_buffer, sizeof(rx_buffer));

    uart->hw_base = UART0_BASE;
    uart->irq = NSCSCC_UART0_IRQ;

    /* device interface */
    uart->parent.init = rt_uart_init;
    uart->parent.open = rt_uart_open;
    uart->parent.close = rt_uart_close;
    uart->parent.read = rt_uart_read;
    uart->parent.write = rt_uart_write;
    uart->parent.control = RT_NULL;
    uart->parent.user_data = RT_NULL;

    rt_device_register(&uart->parent, "uart0", RT_DEVICE_FLAG_RDWR | RT_DEVICE_FLAG_STREAM | RT_DEVICE_FLAG_INT_RX);
}

#endif
