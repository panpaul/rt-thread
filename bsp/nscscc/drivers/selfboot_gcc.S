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
#include "rtconfig.h"

#include "cache.h"
#include "selfboot.h"

/* Macros */
#ifdef RT_SELF_BOOT_DEBUG
#define PRINTSTR(str)		\
	.pushsection		\
	.selfboot_data;		\
	.align 4; 		\
98:	.asciz str;		\
	.popsection;		\
	la	a0, 98b;	\
	li	k0, 0x3fa00000;	\
	add	a0, a0, k0;	\
	bal	stringserial;	\
	nop
#else
#define PRINTSTR(x)
#endif

#define DELAY(count) \
	li v0, count; 99: bnez v0, 99b;addiu v0, -1


#define EXC_TLB_REFILL	0x0
#define EXC_CACHE_ERR	0x1
#define EXC_GEN		0x2
#define EXC_INT		0x3

.section ".selfboot", "ax"
.set noreorder
.set mips32
.globl _start
.extern start

/* jump start */
_start:
	mtc0	zero, CP0_STATUS
	mtc0	zero, CP0_CAUSE
	li		t0, ST0_BEV
	mtc0	t0, CP0_STATUS
	bal	locate
	nop
FailAddr:
 	b	FailAddr
	nop

/* 0xbfc00200 TLB_REFILL exception */
.org 0x200
	li	a0, EXC_TLB_REFILL
	b	exc_common
	nop
1: 	b	1b
	nop

/* 0xbfc00300 Cache Error exception */
.org 0x300
	li	a0, EXC_CACHE_ERR
	b	exc_common
	nop
1: 	b	1b
	nop

/* 0xbfc00380 General exception */
.org 0x380
	li	a0, EXC_GEN
	b	exc_common
	nop
1: 	b	1b
	nop

/* 0xbfc00400 Interrupt exception */
.org 0x400
	li	a0, EXC_INT
	b	exc_common
	nop
1: 	b	1b
	nop

exc_common:
	li	s1, EXC_TLB_REFILL
	bne	a0, s1, 1f
	nop
	PRINTSTR("\r\nEARLY_PANIC: Exception TLB Refill")
	b	print_cause
	nop
1:
	li	s1, EXC_CACHE_ERR
	bne	a0, s1, 1f
	nop
	PRINTSTR("\r\nEARLY_PANIC: CACHE Error: ")
	mfc0 a0, CP0_CACHEERR
	bal	hexserial
	nop
	b	print_cause
	nop
1:
	li	s1, EXC_GEN
	bne	a0, s1, 1f
	nop
	PRINTSTR("\r\nEARLY_PANIC: General Exception")
	b	print_cause
	nop
1:
	li	s1, EXC_INT
	bne	a0, s1, print_cause
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
	## mfc0	a0, CP0_EPC
	## lw	a0, 0(a0)
	## bal	hexserial
	## nop

	PRINTSTR("\r\nEARLY: LOOP! Noting to do")
#endif

1:
	b	1b
	nop

locate:
	/* already loaded into correct place */
	la	v0, FailAddr
	beq	v0, ra, JumpEntry
	nop

	/* start to initialize debug uart port */
	la	v0, NSCSCC_UART0_BASE
1:
	li	v1, FIFO_ENABLE | FIFO_RCV_RST | FIFO_XMT_RST | FIFO_TRIGGER_1
	sb	v1, NSCSCC_UART_FCR_OFFSET(v0)
	li	v1, CFCR_DLAB
	sb	v1, NSCSCC_UART_LCR_OFFSET(v0)
	li	v1, 0x23
	sb	v1, NSCSCC_UART_LSB_OFFSET(v0)
	srl	v1, 8
	sb	v1, NSCSCC_UART_MSB_OFFSET(v0)
	li	v1, CFCR_8BITS
	sb	v1, NSCSCC_UART_LCR_OFFSET(v0)

	# li	v1, MCR_DTR|MCR_RTS
	# sb	v1, NSCSCC_UART_MCR_OFFSET(v0)

	li	v1, 0x0
	sb	v1, NSCSCC_UART_IER_OFFSET(v0)

	PRINTSTR("\r\nINFO: NSCSCC Starting :) \r\n")
	
	/* Initialize Cache */
	PRINTSTR("INFO: Initializing Cache ...\r\n")
	bal	cache_init
	nop

	/* Copy Code */
	PRINTSTR("INFO: Copying Code ... ")

Bootloader:
	/*
	 * Link: Text Start = 0x80200000
	 * Boot: Text Start = 0xbfc00000
	 */
	li	k0, 0x20000000 # k0 + (Link Start) = Address in linking
	li	k1, 0x3fa00000 # k1 + (Link Start) = Address mapped in SPI
 
	la	t0, __selfboot_end
	la	t1, _end
	la	t2, __selfboot_end
 
	add	t0, t0, k0
	add	t1, t1, k0
	add	t2, t2, k1
1:
	lw	k0, 0(t2)
	addiu	t2, t2, 4
	sw	k0, 0(t0)
	addiu	t0, t0, 4
	bne	t0, t1, 1b
	nop

JumpEntry:
	la	v0, NSCSCC_UART0_BASE
	li	a0, 256
	srl	a0, 20 # a0 = memory size stored in MB

	PRINTSTR("Done\r\n")
	PRINTSTR("INFO: Early Boot Ended\r\n")
	PRINTSTR("INFO: Jump to RT-Thread\r\n")
	/* execute main */
	la	v0, _rtthread_entry
	jalr	v0
 	nop

	loop:
	b	loop
	nop

/* functions here */
LEAF(stringserial)
	/* print out the string in address passed in a0  */
	nop
	move	a2, ra
	addi	a1, a0, 0
	lbu	a0, 0(a1)
1:
	beqz	a0, 2f
	nop
	bal	tgt_putchar
	addiu	a1, 1
	b	1b
	lbu	a0, 0(a1)
2:
	j	a2
	nop
END(stringserial)


LEAF(hexserial)
/* print out single hex char passed in register a0 */
	nop
	move	a2, ra
	move	a1, a0
	li	a3, 7
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
	slt	v0, a0, 10
	beq	v0, zero, 2f
	nop
	addi	a0, a0, 48
	b	3f
	nop
2:
	addi a0, a0, 97
3:
	bal	tgt_putchar
	nop

	bnez	a3, 1b
	addu	a3, -1

	j a2
	nop
END(hexserial)

LEAF(tgt_putchar)
	/* print out a char in a0 */
	la	v0, NSCSCC_UART0_BASE
	lbu	v1, NSCSCC_UART_LSR_OFFSET(v0)
1:
	and	v1, LSR_TXRDY
	beqz	v1, 1b
	lbu	v1, NSCSCC_UART_LSR_OFFSET(v0)

	sb	a0, NSCSCC_UART_DAT_OFFSET(v0)
	j	ra
	nop
END(tgt_putchar)

LEAF(CPU_SetSR)
	/* modify SR value, arg 1 = set bits, arg 2 = clear bits. */
	mfc0	v0, CP0_STATUS
	not	v1, a1
	and	v1, v0
	or	v1, a0
	mtc0	v1, CP0_STATUS
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
	mfc0	t4,CP0_CONFIG,1	/* move CP0 CONFIG to t4 */
	lui	v0, 0x7		/* v0 = 0x7 << 16 */
	and	v0, t4, v0	/* v0 = t4 & v0 */
	srl	t3, v0, 16	/* t3 = v0 >> 16  Icache组相联数 IA */

	li	t5, 0x800	//32*64
	srl	v1, t4,22	//v1 = t4 >> 22
	andi	v1, 7		//Icache每路的组数 64x2^S IS
	sll	t5, v1		//InstCacheSetSize
	sll	t5, t3		//t5 InstCacheSize


	andi	v0, t4, 0x0380
	srl	t7, v0, 7	//DA

	li	t6, 0x800	// 32*64
	srl	v1, t4,13
	andi	v1, 7		// DS
	sll	t6, v1		// DataCacheSetSize
	sll	t6, t7		// t5 DataCacheSize

####part 3####
	lui	a0, 0x8000	//a0 = 0x8000 << 16
	addu	a1, $0, t5
	addu	a2, $0, t6
cache_init_d2way:
	/* a0=0x80000000, a1=icache_size, a2=dcache_size */
	/* a3, v0 and v1 used as local registers */
	mtc0	$0, CP0_TAGHI
	addu	v0, $0, a0	/* v0 = 0 + a0 */
	addu	v1, a0, a2	/* v1 = a0 + a2 */
1:	slt	a3, v0, v1	/* a3 = v0 < v1 ? 1 : 0 */
	beq	a3, $0, 1f	/* if (a3 == 0) goto 1f */
	nop
	mtc0	$0, CP0_TAGLO
	cache	Index_Store_Tag_D, 0x0(v0) /* 1 way */
4:	beq	$0, $0, 1b
	addiu	v0, v0, 0x20
1:
cache_flush_i2way:
	addu	v0, $0, a0
	addu	v1, a0, a1
1:
	slt	a3, v0, v1
	beq	a3, $0, 1f
	nop
	cache	Index_Invalidate_I, 0x0(v0) /* 1 way */
4:
	beq	$0, $0, 1b
	addiu	v0, v0, 0x20
1:
cache_flush_d2way:
	addu	v0, $0, a0
	addu	v1, a0, a2
1:	slt	a3, v0, v1
	beq	a3, $0, 1f
	nop
	cache	Index_Writeback_Inv_D, 0x0(v0) /* 1 way */
4:	beq	$0, $0, 1b
	addiu	v0, v0, 0x20
1:
cache_init_finish:
	jr t1
	nop
#endif
