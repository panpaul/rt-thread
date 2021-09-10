 /*
 * Copyright (c) 2006-2018, RT-Thread Development Team
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 * Change Logs:
 * Date           Author       Notes
 *                             first version
 * 2021-09-09     Paul         modified for NSCSCC
 */
// 串口相关源码

#include <stdio.h>
#include <stdarg.h>
#include "nscscc_public.h"
#include "nscscc_regs.h"
#include "nscscc_uart.h"
#include "nscscc_clock.h"
#include "nscscc.h"


// 串口线路状态寄存器的位域
#define NSCSCC_UART_LSR_TE                (1 << 6)
#define NSCSCC_UART_LSR_TFE               (1 << 5)


// 打印缓存的大小
#define NSCSCC_UART_PRINT_BUF_SIZE        (256)

/*
 * 初始化串口模块
 */
void uart_init()
{
    void *uart_base = (uint32_t*)NSCSCC_UART00_BASE;
    unsigned long baudrate_div = 0;

    // 禁止所有中断
    reg_write_8(0,      uart_base + NSCSCC_UART_IER_OFFSET);
    
    // 接收FIFO的中断申请Trigger为14字节，清空发送和接收FIFO，并复位
    reg_write_8(0xc3,   uart_base + NSCSCC_UART_FCR_OFFSET);
    
    // 设置波特率
    reg_write_8(0x80,   uart_base + NSCSCC_UART_LCR_OFFSET);
    baudrate_div = clk_get_cpu_rate() / 16 / 57600 / 2;
    reg_write_8((baudrate_div >> 8) & 0xff, uart_base + NSCSCC_UART_MSB_OFFSET);
    reg_write_8(baudrate_div & 0xff,        uart_base + NSCSCC_UART_LSB_OFFSET);

    // 8个数据位，1个停止位，无校验
    reg_write_8(0x03,   uart_base + NSCSCC_UART_LCR_OFFSET);

    // 使能接收中断
    reg_write_8(IER_IRxE|IER_ILE , uart_base + NSCSCC_UART_IER_OFFSET);

    return ;
}


/*
 * 判断FIFO是否为空
 * @uartx 串口号
 * @ret TRUE or FALSE
 */
BOOL uart_is_transmit_empty()
{
    void *uart_base = (uint32_t*)NSCSCC_UART00_BASE;
    unsigned char status = reg_read_8(uart_base + NSCSCC_UART_LSR_OFFSET);

    if (status & (NSCSCC_UART_LSR_TE | NSCSCC_UART_LSR_TFE))
    {
        return TRUE;
    }
    else
    {
        return FALSE;
    }
}


/*
 * 发送一个字节
 * @uartx 串口号
 * @ch 待发送的字符串
 */
void uart_putc(unsigned char ch)
{
    void *uart_base = (uint32_t*)NSCSCC_UART00_BASE;
    
    // 等待
    while (FALSE == uart_is_transmit_empty())
        ;

    // 发送
    reg_write_8(ch, uart_base + NSCSCC_UART_DAT_OFFSET);

    return ;
}


/*
 * 打印一个字符串到指定串口
 * @uartx 串口号
 * @str 待打印的字符串
 */
void uart_print(const char *str)
{
    while ('\0' != *str)                // 判断是否为字符串结束符
    {
        uart_putc(*str);   // 发送一个字符
        str++;
    }

    return ;
}

