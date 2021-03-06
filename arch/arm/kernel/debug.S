/*
 *  linux/arch/arm/kernel/debug-armv.S
 *
 *  Copyright (C) 1994-1999 Russell King
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation.
 *
 *  32-bit debugging code
 */
#include <linux/config.h>
#include <linux/linkage.h>
#include <asm/hardware.h>

		.text

/*
 * Some debugging routines (useful if you've got MM problems and
 * printk isn't working).  For DEBUGGING ONLY!!!  Do not leave
 * references to these in a production kernel!
 */
#if defined(CONFIG_ARCH_RPC)
		.macro	addruart,rx
		mov	\rx, #0xe0000000
		orr	\rx, \rx, #0x00010000
		orr	\rx, \rx, #0x00000fe0
		.endm

		.macro	senduart,rd,rx
		strb	\rd, [\rx]
		.endm

		.macro	busyuart,rd,rx
1001:		ldrb	\rd, [\rx, #0x14]
		and	\rd, \rd, #0x60
		teq	\rd, #0x60
		bne	1001b
		.endm

		.macro	waituart,rd,rx
1001:		ldrb	\rd, [\rx, #0x18]
		tst	\rd, #0x10
		beq	1001b
		.endm

#elif defined(CONFIG_DEBUG_ICEDCC)
		@@ debug using ARM EmbeddedICE DCC channel
		.macro	addruart, rx
		.endm

		.macro	senduart, rd, rx
		mcr	p14, 0, \rd, c1, c0, 0
		.endm

		.macro	busyuart, rd, rx
1001:
		mrc	p14, 0, \rx, c0, c0, 0
		tst	\rx, #2
		beq	1001b

		.endm

		.macro	waituart, rd, rx
		mov	\rd, #0x2000000
1001:
		subs	\rd, \rd, #1
		bmi	1002f
		mrc	p14, 0, \rx, c0, c0, 0
		tst	\rx, #2
		bne	1001b
1002:
		.endm

#elif defined(CONFIG_ARCH_EBSA110)
		.macro	addruart,rx
		mov	\rx, #0xf0000000
		orr	\rx, \rx, #0x00000be0
		.endm

		.macro	senduart,rd,rx
		strb	\rd, [\rx]
		.endm

		.macro	busyuart,rd,rx
1002:		ldrb	\rd, [\rx, #0x14]
		and	\rd, \rd, #0x60
		teq	\rd, #0x60
		bne	1002b
		.endm

		.macro	waituart,rd,rx
1001:		ldrb	\rd, [\rx, #0x18]
		tst	\rd, #0x10
		beq	1001b
		.endm
 	
#elif defined(CONFIG_ARCH_SHARK)
		.macro	addruart,rx
		mov	\rx, #0xe0000000
		orr	\rx, \rx, #0x000003f8
		.endm

		.macro	senduart,rd,rx
		strb	\rd, [\rx]
		.endm

		.macro	busyuart,rd,rx
		mov	\rd, #0
1001:		add	\rd, \rd, #1
		teq	\rd, #0x10000
		bne	1001b
		.endm

		.macro	waituart,rd,rx
		.endm

#elif defined(CONFIG_FOOTBRIDGE)

#include <asm/hardware/dec21285.h>

#ifndef CONFIG_DEBUG_DC21285_PORT
	/* For NetWinder debugging */
		.macro	addruart,rx
		mrc	p15, 0, \rx, c1, c0
		tst	\rx, #1			@ MMU enabled?
		moveq	\rx, #0x7c000000	@ physical
		movne	\rx, #0xff000000	@ virtual
		orr	\rx, \rx, #0x000003f8
		.endm

		.macro	senduart,rd,rx
		strb	\rd, [\rx]
		.endm

		.macro	busyuart,rd,rx
1002:		ldrb	\rd, [\rx, #0x5]
		and	\rd, \rd, #0x60
		teq	\rd, #0x60
		bne	1002b
		.endm

		.macro	waituart,rd,rx
1001:		ldrb	\rd, [\rx, #0x6]
		tst	\rd, #0x10
		beq	1001b
		.endm
#else
	/* For EBSA285 debugging */
		.equ	dc21285_high, ARMCSR_BASE & 0xff000000
		.equ	dc21285_low,  ARMCSR_BASE & 0x00ffffff

		.macro	addruart,rx
		mov	\rx, #dc21285_high
		.if	dc21285_low
		orr	\rx, \rx, #dc21285_low
		.endif
		.endm

		.macro	senduart,rd,rx
		str	\rd, [\rx, #0x160]	@ UARTDR
		.endm

		.macro	busyuart,rd,rx
1001:		ldr	\rd, [\rx, #0x178]	@ UARTFLG
		tst	\rd, #1 << 3
		bne	1001b
		.endm

		.macro	waituart,rd,rx
		.endm
#endif
#elif defined(CONFIG_ARCH_FTVPCI)
		.macro	addruart,rx
		mrc	p15, 0, \rx, c1, c0
		tst	\rx, #1			@ MMU enabled?
		movne	\rx, #0xe0000000
		moveq	\rx, #0x10000000
		.endm

		.macro	senduart,rd,rx
		str	\rd, [\rx, #0xc]
		.endm

		.macro	busyuart,rd,rx
1001:		ldr	\rd, [\rx, #0x4]
		tst	\rd, #1 << 2
		beq	1001b
		.endm

		.macro	waituart,rd,rx
		.endm

#elif defined(CONFIG_ARCH_SA1100)

		.macro	addruart,rx
		mrc	p15, 0, \rx, c1, c0
		tst	\rx, #1			@ MMU enabled?
		moveq	\rx, #0x80000000	@ physical base address
		movne	\rx, #0xf8000000	@ virtual address

		@ We probe for the active serial port here, coherently with
		@ the comment in include/asm-arm/arch-sa1100/uncompress.h.
		@ We assume r1 can be clobbered.

		@ see if Ser3 is active
		add	\rx, \rx, #0x00050000
		ldr	r1, [\rx, #UTCR3]
		tst	r1, #UTCR3_TXE

		@ if Ser3 is inactive, then try Ser1
		addeq	\rx, \rx, #(0x00010000 - 0x00050000)
		ldreq	r1, [\rx, #UTCR3]
		tsteq	r1, #UTCR3_TXE

		@ if Ser1 is inactive, then try Ser2
		addeq	\rx, \rx, #(0x00030000 - 0x00010000)
		ldreq	r1, [\rx, #UTCR3]
		tsteq	r1, #UTCR3_TXE

		@ if all ports are inactive, then there is nothing we can do
		moveq	pc, lr
		.endm

		.macro	senduart,rd,rx
		str	\rd, [\rx, #UTDR]
		.endm

		.macro	waituart,rd,rx
1001:		ldr	\rd, [\rx, #UTSR1]
		tst	\rd, #UTSR1_TNF
		beq	1001b
		.endm

		.macro	busyuart,rd,rx
1001:		ldr	\rd, [\rx, #UTSR1]
		tst	\rd, #UTSR1_TBY
		bne	1001b
		.endm

#elif defined(CONFIG_ARCH_PXA)

		.macro	addruart,rx
		mrc	p15, 0, \rx, c1, c0
		tst	\rx, #1			@ MMU enabled?
		moveq	\rx, #0x40000000		@ physical
		movne	\rx, #io_p2v(0x40000000)	@ virtual
		orr	\rx, \rx, #0x00100000
		.endm

		.macro	senduart,rd,rx
		str	\rd, [\rx, #0]
		.endm

		.macro	busyuart,rd,rx
1002:		ldr	\rd, [\rx, #0x14]
		tst	\rd, #(1 << 6)
		beq	1002b
		.endm

		.macro	waituart,rd,rx
1001:		ldr	\rd, [\rx, #0x14]
		tst	\rd, #(1 << 5)
		beq	1001b
		.endm
#elif defined(CONFIG_ARCH_CLPS7500)
		.macro	addruart,rx
		mov	\rx, #0xe0000000
		orr	\rx, \rx, #0x00010000
		orr	\rx, \rx, #0x00000be0
		.endm

		.macro	senduart,rd,rx
		strb	\rd, [\rx]
		.endm

		.macro	busyuart,rd,rx
		.endm

		.macro	waituart,rd,rx
1001:		ldrb	\rd, [\rx, #0x14]
		tst	\rd, #0x20
		beq	1001b
		.endm

#elif defined(CONFIG_ARCH_L7200)

		.equ	io_virt, IO_BASE
		.equ	io_phys, IO_START

		.macro	addruart,rx
		mrc	p15, 0, \rx, c1, c0
		tst	\rx, #1			@ MMU enabled?
		moveq	\rx, #io_phys		@ physical base address
		movne	\rx, #io_virt		@ virtual address
		add	\rx, \rx, #0x00044000	@ UART1
@		add	\rx, \rx, #0x00045000	@ UART2
		.endm

		.macro	senduart,rd,rx
		str	\rd, [\rx, #0x0]	@ UARTDR
		.endm

		.macro	waituart,rd,rx
1001:		ldr	\rd, [\rx, #0x18]	@ UARTFLG
		tst	\rd, #1 << 5		@ UARTFLGUTXFF - 1 when full
		bne	1001b
		.endm

		.macro	busyuart,rd,rx
1001:		ldr	\rd, [\rx, #0x18]	@ UARTFLG
		tst	\rd, #1 << 3		@ UARTFLGUBUSY - 1 when busy
		bne	1001b
		.endm

#elif defined(CONFIG_ARCH_INTEGRATOR)

#include <asm/hardware/amba_serial.h>

		.macro	addruart,rx
		mrc	p15, 0, \rx, c1, c0
		tst	\rx, #1			@ MMU enabled?
		moveq	\rx, #0x16000000	@ physical base address
		movne	\rx, #0xf0000000	@ virtual base
		addne	\rx, \rx, #0x16000000 >> 4
		.endm

		.macro	senduart,rd,rx
		strb	\rd, [\rx, #UART01x_DR]
		.endm

		.macro	waituart,rd,rx
1001:		ldr	\rd, [\rx, #0x18]	@ UARTFLG
		tst	\rd, #1 << 5		@ UARTFLGUTXFF - 1 when full
		bne	1001b
		.endm

		.macro	busyuart,rd,rx
1001:		ldr	\rd, [\rx, #0x18]	@ UARTFLG
		tst	\rd, #1 << 3		@ UARTFLGUBUSY - 1 when busy
		bne	1001b
		.endm

#elif defined(CONFIG_ARCH_CLPS711X)

#include <asm/hardware/clps7111.h>

		.macro	addruart,rx
		mrc	p15, 0, \rx, c1, c0
		tst	\rx, #1			@ MMU enabled?
		moveq	\rx, #CLPS7111_PHYS_BASE
		movne	\rx, #CLPS7111_VIRT_BASE
#ifndef CONFIG_DEBUG_CLPS711X_UART2
		add	\rx, \rx, #0x0000	@ UART1
#else
		add	\rx, \rx, #0x1000	@ UART2
#endif
		.endm

		.macro	senduart,rd,rx
		str	\rd, [\rx, #0x0480]	@ UARTDR
		.endm

		.macro	waituart,rd,rx
1001:		ldr	\rd, [\rx, #0x0140]	@ SYSFLGx
		tst	\rd, #1 << 11		@ UBUSYx
		bne	1001b
		.endm

		.macro	busyuart,rd,rx
		tst	\rx, #0x1000		@ UART2 does not have CTS here
		bne	1002f
1001:		ldr	\rd, [\rx, #0x0140]	@ SYSFLGx
		tst	\rd, #1 << 8		@ CTS
		bne	1001b
1002:
		.endm

#elif defined(CONFIG_ARCH_CAMELOT)

#include <asm/arch/excalibur.h>
#define UART00_TYPE
#include <asm/arch/uart00.h>

		.macro	addruart,rx
		mrc	p15, 0, \rx, c1, c0
		tst	\rx, #1			@ MMU enabled?
		ldr	\rx, =EXC_UART00_BASE	@ physical base address
		orrne	\rx, \rx, #0xff000000	@ virtual base
		orrne	\rx, \rx, #0x00f00000	
		.endm

		.macro	senduart,rd,rx
		str	\rd, [\rx, #UART_TD(0)]
		.endm

		.macro	waituart,rd,rx
1001:		ldr	\rd, [\rx, #UART_TSR(0)]
		and 	\rd, \rd,  #UART_TSR_TX_LEVEL_MSK
		cmp	\rd, #15
		beq	1001b
		.endm

		.macro	busyuart,rd,rx
1001:		ldr	\rd, [\rx, #UART_TSR(0)]
		ands 	\rd, \rd,  #UART_TSR_TX_LEVEL_MSK
		bne	1001b
		.endm

#elif defined(CONFIG_ARCH_IOP3XX)

		.macro	addruart,rx
		mov	\rx, #0xfe000000	@ physical
#ifdef CONFIG_ARCH_IQ80310
		orr	\rx, \rx, #0x00810000	@ location of the UART
#elif defined(CONFIG_ARCH_IQ80321)
		orr	\rx, \rx, #0x00800000	@ location of the UART
#else
#error Unknown IOP3XX implementation
#endif
		.endm

		.macro	senduart,rd,rx
		strb	\rd, [\rx]
		.endm

		.macro	busyuart,rd,rx
1002:		ldrb	\rd, [\rx, #0x5]
		and	\rd, \rd, #0x60
		teq	\rd, #0x60
		bne	1002b
		.endm

		.macro	waituart,rd,rx
#ifndef	CONFIG_ARCH_IQ80321
1001:		ldrb	\rd, [\rx, #0x6]
		tst	\rd, #0x10
		beq	1001b
#endif
		.endm

#elif defined(CONFIG_ARCH_ADI_EVB)

		.macro	addruart,rx
		mrc	p15, 0, \rx, c1, c0
		tst	\rx, #1			@ MMU enabled?
		mov	\rx, #0x00400000	@ physical base address
		orrne	\rx, \rx, #0xff000000	@ virtual base
		.endm

		.macro	senduart,rd,rx
		strb	\rd, [\rx]
		.endm

		.macro	busyuart,rd,rx
1002:		ldrb	\rd, [\rx, #0x5]
		and	\rd, \rd, #0x60
		teq	\rd, #0x60
		bne	1002b
		.endm

		.macro	waituart,rd,rx
1001:		ldrb	\rd, [\rx, #0x6]
		tst	\rd, #0x10
		beq	1001b
		.endm

#elif defined(CONFIG_ARCH_IXP4XX)

                .macro  addruart,rx
                mrc     p15, 0, \rx, c1, c0
                tst     \rx, #1                 @ MMU enabled?
                moveq   \rx, #0xc8000000
                movne   \rx, #0xff000000
                add     \rx,\rx,#3              @ Uart regs are at off set of 3 if
						@ byte writes used - Big Endian.
                .endm

               .macro  senduart,rd,rx
                strb    \rd, [\rx]
                .endm

                .macro  waituart,rd,rx
1002:           ldrb    \rd, [\rx, #0x14]
                and     \rd, \rd, #0x60		@ check THRE and TEMT bits
                teq     \rd, #0x60
                bne     1002b
                .endm

                .macro  busyuart,rd,rx
                .endm

#elif defined(CONFIG_ARCH_OMAP)

		.macro	addruart,rx
		mrc	p15, 0, \rx, c1, c0
		tst	\rx, #1			@ MMU enabled?
		moveq	\rx, #0xff000000	@ physical base address
		movne	\rx, #0xfe000000	@ virtual base
		orr	\rx, \rx, #0x00fb0000
#ifdef CONFIG_OMAP_LL_DEBUG_UART3
		orr	\rx, \rx, #0x00009000	@ UART 3
#endif
#if defined(CONFIG_OMAP_LL_DEBUG_UART2) || defined(CONFIG_OMAP_LL_DEBUG_UART3)
		orr	\rx, \rx, #0x00000800	@ UART 2 & 3
#endif
		.endm

		.macro	senduart,rd,rx
		strb	\rd, [\rx]
		.endm

		.macro	busyuart,rd,rx
1001:		ldrb	\rd, [\rx, #(0x5 << 2)]	@ OMAP-1510 and friends
		and	\rd, \rd, #0x60
		teq	\rd, #0x60
		beq	1002f
		ldrb	\rd, [\rx, #(0x5 << 0)]	@ OMAP-730 only
		and	\rd, \rd, #0x60
		teq	\rd, #0x60
		bne	1001b
1002:
		.endm

		.macro	waituart,rd,rx
		.endm

#elif defined(CONFIG_ARCH_S3C2410)
#include <asm/arch/map.h>
#include <asm/arch/regs-serial.h>

		.macro addruart, rx
		mrc	p15, 0, \rx, c1, c0
		tst	\rx, #1
		ldreq	\rx, = S3C2410_PA_UART
		ldrne	\rx, = S3C2410_VA_UART
#if CONFIG_DEBUG_S3C2410_UART != 0
		add	\rx, \rx, #(S3C2410_UART1_OFF * CONFIG_DEBUG_S3C2410_UART)
#endif
		.endm

		.macro	senduart,rd,rx
		str	\rd, [\rx, # S3C2410_UTXH ]
		.endm

		.macro	busyuart, rd, rx
		ldr	\rd, [ \rx, # S3C2410_UFCON ]
		tst	\rd, #S3C2410_UFCON_FIFOMODE	@ fifo enabled?
		beq	1001f				@
		@ FIFO enabled...
1003:
		ldr	\rd, [ \rx, # S3C2410_UFSTAT ]
		tst	\rd, #S3C2410_UFSTAT_TXFULL
		bne	1003b
		b	1002f

1001:
		@ busy waiting for non fifo
		ldr	\rd, [ \rx, # S3C2410_UTRSTAT ]
		tst	\rd, #S3C2410_UTRSTAT_TXFE
		beq	1001b

1002:		@ exit busyuart
		.endm

		.macro	waituart,rd,rx

		ldr	\rd, [ \rx, # S3C2410_UFCON ]
		tst	\rd, #S3C2410_UFCON_FIFOMODE	@ fifo enabled?
		beq	1001f				@
		@ FIFO enabled...
1003:
		ldr	\rd, [ \rx, # S3C2410_UFSTAT ]
		ands	\rd, \rd, #15<<S3C2410_UFSTAT_TXSHIFT
		bne	1003b
		b	1002f

1001:
		@ idle waiting for non fifo
		ldr	\rd, [ \rx, # S3C2410_UTRSTAT ]
		tst	\rd, #S3C2410_UTRSTAT_TXFE
		beq	1001b

1002:		@ exit busyuart
		.endm

#elif defined(CONFIG_ARCH_LH7A40X)
	@ It is not known if this will be appropriate for every 40x
	@ board.

		.macro  addruart,rx
		mrc     p15, 0, \rx, c1, c0
		tst     \rx, #1                 @ MMU enabled?
		ldr     \rx, =0x80000700        @ physical base address
		orrne   \rx, \rx, #0xf8000000   @ virtual base
		.endm

		.macro  senduart,rd,rx
		strb    \rd, [\rx]              @ DATA
		.endm

		.macro  busyuart,rd,rx          @ spin while busy
1001:		ldr     \rd, [\rx, #0x10]       @ STATUS
		tst     \rd, #1 << 3            @ BUSY (TX FIFO not empty)
		bne     1001b                   @ yes, spin
		.endm

		.macro  waituart,rd,rx          @ wait for Tx FIFO room
1001:		ldrb    \rd, [\rx, #0x10]       @ STATUS
		tst     \rd, #1 << 5            @ TXFF (TX FIFO full)
		bne     1001b                   @ yes, spin
		.endm


#elif defined(CONFIG_ARCH_VERSATILE_PB)

#include <asm/hardware/amba_serial.h>

		.macro	addruart,rx
		mrc	p15, 0, \rx, c1, c0
		tst	\rx, #1			@ MMU enabled?
		moveq	\rx,      #0x10000000
		movne	\rx,      #0xf1000000	@ virtual base
		orr	\rx, \rx, #0x001F0000
		orr	\rx, \rx, #0x00001000
		.endm

		.macro	senduart,rd,rx
		strb	\rd, [\rx, #UART01x_DR]
		.endm

		.macro	waituart,rd,rx
1001:		ldr	\rd, [\rx, #0x18]	@ UARTFLG
		tst	\rd, #1 << 5		@ UARTFLGUTXFF - 1 when full
		bne	1001b
		.endm

		.macro	busyuart,rd,rx
1001:		ldr	\rd, [\rx, #0x18]	@ UARTFLG
		tst	\rd, #1 << 3		@ UARTFLGUBUSY - 1 when busy
		bne	1001b
		.endm
#else
#error Unknown architecture
#endif

/*
 * Useful debugging routines
 */
ENTRY(printhex8)
		mov	r1, #8
		b	printhex

ENTRY(printhex4)
		mov	r1, #4
		b	printhex

ENTRY(printhex2)
		mov	r1, #2
printhex:	adr	r2, hexbuf
		add	r3, r2, r1
		mov	r1, #0
		strb	r1, [r3]
1:		and	r1, r0, #15
		mov	r0, r0, lsr #4
		cmp	r1, #10
		addlt	r1, r1, #'0'
		addge	r1, r1, #'a' - 10
		strb	r1, [r3, #-1]!
		teq	r3, r2
		bne	1b
		mov	r0, r2
		b	printascii

		.ltorg

ENTRY(printascii)
		addruart r3
		b	2f
1:		waituart r2, r3
		senduart r1, r3
		busyuart r2, r3
		teq	r1, #'\n'
		moveq	r1, #'\r'
		beq	1b
2:		teq	r0, #0
		ldrneb	r1, [r0], #1
		teqne	r1, #0
		bne	1b
		mov	pc, lr

ENTRY(printch)
		addruart r3
		mov	r1, r0
		mov	r0, #0
		b	1b

hexbuf:		.space 16
