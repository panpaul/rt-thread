/*
 * Copyright (c) 2006-2019, RT-Thread Development Team
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 * Origin Authors: Loongson Technology Corporation Limited,
 * caogos <1207280597@qq.com>, Jiaxun Yang <jiaxun.yang@flygoat.com>,
 *
 * Also thanks to Liu Shiwei <liushiwei@gmail.com> and other Loongson
 * Community developers.
 *
 * Change Logs:
 * Date           Author       Notes
 * 2019-12-04     Jiaxun Yang  Initial version
 * 2021-09-09     Paul         modified for NSCSCC
 */

#include <rtconfig.h>

#ifdef RT_USING_SELF_BOOT

#ifndef __ASSEMBLY__
#define __ASSEMBLY__
#endif

#include <mips.h>
#include "selfboot.h"
#include "nscscc.h"
#include "nscscc_regs.h"
#include "cache.h"

/*
 *   Register usage:
 *
 *	s0	link versus load offset, used to relocate absolute adresses.
 *	s1	free
 *	s2	memory size
 *	s3	free
 *	s4	free
 *	s5	dbg
 *	s6	sdCfg
 *	s7	rasave
 *	s8	free
 */


/* Macros */
#ifdef RT_SELF_BOOT_DEBUG
#define	PRINTSTR(str) \
    .pushsection .selfboot_data; .align 4; 98: .asciz str; .popsection; la a0, 98b; bal stringserial; nop
#else
#define PRINTSTR(x)
#endif

#define	DELAY(count)	\
    li v0, count;	\
99:			\
    bnez	v0, 99b;\
    addiu	v0, -1

.section ".selfboot", "ax"
.set	noreorder
.set	mips32
.globl	_start
.extern	start
_start:

/* NMI/Reset vector starts here*/
  mtc0  zero, CP0_STATUS /* set cp0 status register to zero */
  mtc0  zero, CP0_CAUSE /* set cp0 cause register to zero */

  li  t0, ST0_BEV /* set exception vector to in flash location */
  mtc0 t0, CP0_STATUS

  bal	locate			/* branch out of vector and get current address to ra */
  nop

/* in-flash exception vectors start here */
/* save the exception types to a0 and print out PANIC message in exc_common */
#define EXC_TLB_REFILL 0x0
#define EXC_CACHE_ERR	0x1
#define EXC_GEN	0x2
#define EXC_INT	0x3

.org 0x200 /* 0xbfc00200 TLB_REFILL exception */
  li a0, EXC_TLB_REFILL
  b exc_common
  nop

.org 0x300 /* 0xbfc00300 Cache Error exception */
  li a0, EXC_CACHE_ERR
  b exc_common
  nop

.org 0x380 /* 0xbfc00300 General exception */
  li	a0,EXC_GEN
  b exc_common
  nop

.org 0x400 /* 0xbfc00400 Interrupt exception */
  li a0, EXC_INT
  b exc_common
  nop

1: /* impossible to reach here, so make a dead loop */
  b 1b
  nop

exc_common: /* try one cause and pass to next */
  li	s1, EXC_TLB_REFILL
  bne a0, s1, 1f
  nop
  PRINTSTR("\r\nEARLY_PANIC: Exception TLB Refill")
  b print_cause
  nop
1:
  li	s1, EXC_CACHE_ERR
  bne a0, s1, 1f
  nop
  PRINTSTR("\r\nEARLY_PANIC: CACHE Error: ")
  mfc0 a0, CP0_CACHEERR
  bal hexserial
  nop
  b print_cause
  nop
1:
  li	s1, EXC_GEN
  bne a0, s1, 1f
  nop
  PRINTSTR("\r\nEARLY_PANIC: General Exception")
  b print_cause
  nop
1:
  li	s1, EXC_INT
  bne a0, s1, print_cause /* if all exceptions in a0 not reached,
                          * print_cause directly*/
  nop
  PRINTSTR("\r\nEARLY_PANIC: Interrupt Exception")
print_cause:
#ifdef RT_SELF_BOOT_DEBUG
  PRINTSTR("\r\nCAUSE=")
  mfc0	a0, CP0_CAUSE
  bal	hexserial
  nop

  PRINTSTR("\r\nSTATUS=")
  mfc0	a0, CP0_STATUS
  bal	hexserial
  nop

  PRINTSTR("\r\nERRORPC=")
  mfc0	a0, CP0_ERROREPC
  bal	hexserial
  nop

  PRINTSTR("\r\nEPC=")
  mfc0	a0, CP0_EPC
  bal	hexserial
  nop

  PRINTSTR("\r\nBADADDR=")
  mfc0	a0, CP0_BADVADDR
  bal	hexserial
  nop

  ## /* TODO: Check TLB Related Exception */
  ## PRINTSTR("\r\nINSTRUCTION(EPC)=")
  ## mfc0 a0, CP0_EPC
  ## lw a0, 0(a0)
  ## bal hexserial
  ## nop

  PRINTSTR("\r\nEARLY: LOOP! Noting to do")
#endif

1: /* Make a dead loop here, wait user to reset the MCU */
  b 1b
  nop

/* locate here, continue the start progress */

locate:
    /* fix the absolute address by ra */
    la  s0, start /* s0 = start */
    subu  s0, ra, s0 /* s0 = ra - s0 */
    and s0, 0xffff0000 /* s0 = s0 & 0xffff0000 */

/* start to initialize debug uart port */
    la	v0, NSCSCC_UART0_BASE /* load UART0 base to v0, only UART0 can be debug port */
1:
    li  v1, FIFO_ENABLE | FIFO_RCV_RST | FIFO_XMT_RST | FIFO_TRIGGER_1
    sb	v1, NSCSCC_UART_FCR_OFFSET(v0) /* write FCR (FIFO control register) */
    li	v1, CFCR_DLAB /* reach freq div register */
    sb	v1, NSCSCC_UART_LCR_OFFSET(v0) /* write LCR (Line control register)*/
    /* Caculate PLL and bit rate */
    li	v1, (EARLY_DEBUG_BAUD)
    sb	v1, NSCSCC_UART_LSB_OFFSET(v0) /* write 8bit low into LSB */
    srl	v1, 8 /* v1 >>= 8 */
    sb	v1, NSCSCC_UART_MSB_OFFSET(v0) /* write 8bit low into MSB */

    li	v1, CFCR_8BITS /* 8n1, no check */
    sb	v1, NSCSCC_UART_LCR_OFFSET(v0) /* write to LCR (Line Control Register) */

//#ifdef EARLY_DEBUG_UART_FLOW_CTRL
    li	v1, MCR_DTR|MCR_RTS /* valid DTR and RTS */
    sb	v1, NSCSCC_UART_MCR_OFFSET(v0) /* write to MCR (MODEM Control Register) */
//#endif

    li	v1, 0x0 /* disable all the interruptions */
    sb	v1, NSCSCC_UART_IER_OFFSET(v0) /* write to IER (Interruptions Enable Registers) */

    PRINTSTR("\r\INFO: NSCSCC Starting :) \r\n")

/* initialize cache */
    bal  cache_init /* branch to cache_init */
    nop

/* enable cache */
    mfc0   a0, CP0_CONFIG /* load cp0 config to a0 */
    and    a0, a0, ~((1<<12) | 7) /* a0 = a0 & ~((1<<12) | 7) */
    or     a0, a0, 2 /* a0 |= 2 */
    mtc0   a0, CP0_CONFIG /* write back to CP0 config */

/*
* relocate: copy selfboot code to memory in kseg0, fix PC and jump to kseg0.
* in order to speed up the copy progress, we will execute copy code in kseg0
*/

    PRINTSTR("\r\INFO: Relocating")

Bootloader:
    li k0, 0xa0000000
    li k1, 0xbfc00000
    
    la t0, __selfboot_end
    la t1, _end
    la t2, __selfboot_end
    
    or t0, t0, k0
    or t1, t1, k0
    or t2, t2, k1
1:
    lw    k0, 0(t2)
    addiu t2, t2, 4
    sw    k0, 0(t0)
    addiu t0, t0, 4
    bne   t0, t1, 1b
    nop

    li a0, 128  /* a0 = msize, will be passed to main */
    srl a0, 20 /* a0 >>= 20, convert to unit in MB */

    /* execute main */
    la		v0, _rtthread_entry /* load address of function main to v0 */
    jalr	v0 /* call address in v0, congrats! all low_level things done!
              * switch brain out of assembly */
    nop
text_copy_end: /* end of self-copy in memory */

    loop: /* impossible to reach here, make a dead loop */
    b	loop
    nop

/* functions here */

LEAF(stringserial) /* print out the string in address passed in a0  */
    nop
    move	a2, ra  /* save the return address to a2 */
    addi    a1, a0, 0
    lbu	a0, 0(a1) /* read the first byte in memory address a1 to a0 */
1:
    beqz	a0, 2f /* if a0 == 0, jump to next tag 2, empty char */
    nop
    bal	tgt_putchar /* print a char */
    addiu	a1, 1 /* a1 += 1 move forward to next byte */
    b	1b /* branch to the last tag 1, continue */
    lbu	a0, 0(a1) /* load the next bit from address a1 to a0, in delay solt,
                * will be execuated before branch */
2:
    j	a2 /* return */
    nop
END(stringserial)


LEAF(hexserial) /* print out single hex char passed in register a0 */
    nop
    move	a2, ra /* move return address from ra to a2  */
    move	a1, a0 /* move hex char from register a0 to a1 */
    li	a3, 7 /* load 7 to a3 */
1:
    rol	a0, a1, 4 /* rotate left ward shift for 4 bit in a1 to a0 */
    move	a1, a0
    and	a0, 0xf

/*
    if (a0 < 10)
        a0 += '0';
    else 
        a0 += 'a';
*/
    slt v0, a0, 10
    beq v0, zero, 2f
    nop
    addi a0, a0, 48
    b 3f
    nop
2:
    addi a0, a0, 97
3:
    bal	tgt_putchar
    nop

    bnez	a3, 1b
    addu	a3, -1

    j	a2
    nop
END(hexserial)

LEAF(tgt_putchar) /* print out a char in a0 */
    la	v0, NSCSCC_UART0_BASE /* load UART register address to a0 */
    lbu	v1, NSCSCC_UART_LSR_OFFSET(v0) /* load value from LSR to v0 */
1:
    and	v1, LSR_TXRDY /* v1 &= LSR_TXRDY determine wether we can send by TFE bit */
    beqz	v1, 1b /* if (v1 == 0) jump to last 1 tag, waiting until TFE is 1 */
    lbu	v1, NSCSCC_UART_LSR_OFFSET(v0) /* load value from LSR to v0 again, in delay solt */

    sb	a0, NSCSCC_UART_DAT_OFFSET(v0) /* write a0 into DAT, send out */
    j	ra /*  */
    nop
END(tgt_putchar)

LEAF(CPU_SetSR) /* modify SR value, arg 1 = set bits, arg 2 = clear bits. */
    mfc0    v0, CP0_STATUS
    not v1, a1
    and v1, v0
    or  v1, a0
    mtc0    v1, CP0_STATUS
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    j   ra
    nop
END(CPU_SetSR)

cache_init:
    move t1, ra
####part 2####
cache_detect_4way:
    mfc0	t4, CP0_CONFIG,1 /* move CP0 CONFIG to t4 */
    lui		v0, 0x7 /* v0 = 0x7 << 16 */
    and		v0, t4, v0 /* v0 = t4 & v0 */
    srl		t3, v0, 16 /* t3 = v0 >> 16  Icache组相联数 IA */

    li		t5, 0x800 		//32*64
    srl		v1, t4,22		//v1 = t4 >> 22
    andi	v1, 7			//Icache每路的组数 64x2^S IS
    sll		t5, v1			//InstCacheSetSize
    sll		t5, t3			//t5 InstCacheSize


    andi	v0, t4, 0x0380
    srl		t7, v0, 7		//DA

    li		t6, 0x800       // 32*64
    srl		v1, t4,13
    andi	v1, 7			//DS
    sll		t6, v1          // DataCacheSetSize
    sll		t6, t7          // t5 DataCacheSize

####part 3####
    lui		a0, 0x8000			//a0 = 0x8000 << 16
    addu	a1, $0, t5
    addu	a2, $0, t6
cache_init_d2way:
/* a0=0x80000000, a1=icache_size, a2=dcache_size */
/* a3, v0 and v1 used as local registers */
    mtc0	$0, CP0_TAGHI
    addu	v0, $0, a0 /* v0 = 0 + a0 */
    addu	v1, a0, a2 /* v1 = a0 + a2 */
1:	slt		a3, v0, v1 /* a3 = v0 < v1 ? 1 : 0 */
    beq		a3, $0, 1f /* if (a3 == 0) goto 1f */
    nop
    mtc0	$0, CP0_TAGLO
    cache	Index_Store_Tag_D, 0x0(v0) /* 1 way */
4:	beq		$0, $0, 1b
    addiu	v0, v0, 0x20
1:
cache_flush_i2way:
    addu	v0, $0, a0
    addu	v1, a0, a1
1:
    slt		a3, v0, v1
    beq		a3, $0, 1f
    nop
    cache	Index_Invalidate_I, 0x0(v0) /* 1 way */
4:
    beq		$0, $0, 1b
    addiu	v0, v0, 0x20
1:
cache_flush_d2way:
    addu	v0, $0, a0
    addu	v1, a0, a2
1:	slt		a3, v0, v1
    beq		a3, $0, 1f
    nop
    cache	Index_Writeback_Inv_D, 0x0(v0) /* 1 way */
4:	beq		$0, $0, 1b
    addiu	v0, v0, 0x20

1:
cache_init_finish:
    jr	t1
    nop
#endif
