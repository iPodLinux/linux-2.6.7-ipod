/*
 *  linux/arch/armnommu/mm/proc-arm1026.S: MMU functions for ARM1026EJ-S
 *
 *  Copyright (C) 2000 ARM Limited
 *  Copyright (C) 2000 Deep Blue Solutions Ltd.
 *  Copyright (C) 2003 Hyok S. Choi <hyok.choi@samsung.com>
 *  modified for NON-PAGED MMU version.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 *
 * These are the low level assembler for performing cache
 * functions on the ARM1026EJ-S.
 */
#include <linux/linkage.h>
#include <linux/config.h>
#include <linux/init.h>
#include <asm/assembler.h>
#include <asm/constants.h>
#include <asm/pgtable.h>
#include <asm/procinfo.h>
#include <asm/ptrace.h>

/*
 * This is the maximum size of an area which will be invalidated
 * using the single invalidate entry instructions.  Anything larger
 * than this, and we go for the whole cache.
 *
 * This value should be chosen such that we choose the cheapest
 * alternative.
 */
#define MAX_AREA_SIZE	32768

/*
 * The size of one data cache line.
 */
#define CACHE_DLINESIZE	32

/*
 * The number of data cache segments.
 */
#define CACHE_DSEGMENTS	16

/*
 * The number of lines in a cache segment.
 */
#define CACHE_DENTRIES	64

/*
 * This is the size at which it becomes more efficient to
 * clean the whole cache, rather than using the individual
 * cache line maintainence instructions.
 */
#define CACHE_DLIMIT	32768

	.text
/*
 * cpu_arm1026_proc_init()
 */
ENTRY(cpu_arm1026_proc_init)
	mov	pc, lr

/*
 * cpu_arm1026_proc_fin()
 */
ENTRY(cpu_arm1026_proc_fin)
	stmfd	sp!, {lr}
	mov	ip, #PSR_F_BIT | PSR_I_BIT | SVC_MODE
	msr	cpsr_c, ip
	bl	arm1026_flush_kern_cache_all
	mrc	p15, 0, r0, c1, c0, 0		@ ctrl register
	bic	r0, r0, #0x1000 		@ ...i............
	bic	r0, r0, #0x000e 		@ ............wca.
	mcr	p15, 0, r0, c1, c0, 0		@ disable caches
	ldmfd	sp!, {pc}

/*
 * cpu_arm1026_reset(loc)
 *
 * Perform a soft reset of the system.	Put the CPU into the
 * same state as it would be if it had been reset, and branch
 * to what would be the reset vector.
 *
 * loc: location to jump to for soft reset
 */
	.align	5
ENTRY(cpu_arm1026_reset)
	mov	ip, #0
	mcr	p15, 0, ip, c7, c7, 0		@ invalidate I,D caches
	mcr	p15, 0, ip, c7, c10, 4		@ drain WB
	mrc	p15, 0, ip, c1, c0, 0		@ ctrl register
	bic	ip, ip, #0x000f 		@ ............wcam
	bic	ip, ip, #0x1100 		@ ...i...s........
	mcr	p15, 0, ip, c1, c0, 0		@ ctrl register
	mov	pc, r0

/*
 * cpu_arm1026_do_idle()
 */
	.align	5
ENTRY(cpu_arm1026_do_idle)
	mcr	p15, 0, r0, c7, c0, 4		@ Wait for interrupt
	mov	pc, lr

/* ================================= CACHE ================================ */

	.align	5
/*
 *	flush_user_cache_all()
 *
 *	Invalidate all cache entries in a particular address
 *	space.
 */
ENTRY(arm1026_flush_user_cache_all)
	/* FALLTHROUGH */
/*
 *	flush_kern_cache_all()
 *
 *	Clean and invalidate the entire cache.
 */
ENTRY(arm1026_flush_kern_cache_all)
	mov	r2, #VM_EXEC
	mov	ip, #0
__flush_whole_cache:
#ifndef CONFIG_CPU_DCACHE_DISABLE
1:	mrc	p15, 0, r15, c7, c14, 3		@ test, clean, invalidate
	bne	1b
#endif
	tst	r2, #VM_EXEC
#ifndef CONFIG_CPU_ICACHE_DISABLE
	mcrne	p15, 0, ip, c7, c5, 0		@ invalidate I cache
#endif
	mcrne	p15, 0, ip, c7, c10, 4		@ drain WB
	mov	pc, lr

/*
 *	flush_user_cache_range(start, end, flags)
 *
 *	Invalidate a range of cache entries in the specified
 *	address space.
 *
 *	- start	- start address (inclusive)
 *	- end	- end address (exclusive)
 *	- flags	- vm_flags for this space
 */
ENTRY(arm1026_flush_user_cache_range)
	mov	ip, #0
	sub	r3, r1, r0			@ calculate total size
	cmp	r3, #CACHE_DLIMIT
	bhs	__flush_whole_cache

#ifndef CONFIG_CPU_DCACHE_DISABLE
1:	mcr	p15, 0, r0, c7, c14, 1		@ clean+invalidate D entry
	add	r0, r0, #CACHE_DLINESIZE
	cmp	r0, r1
	blo	1b
#endif
	tst	r2, #VM_EXEC
#ifndef CONFIG_CPU_ICACHE_DISABLE
	mcrne	p15, 0, ip, c7, c5, 0		@ invalidate I cache
#endif
	mcrne	p15, 0, ip, c7, c10, 4		@ drain WB
	mov	pc, lr

/*
 *	coherent_kern_range(start, end)
 *
 *	Ensure coherency between the Icache and the Dcache in the
 *	region described by start.  If you have non-snooping
 *	Harvard caches, you need to implement this function.
 *
 *	- start	- virtual start address
 *	- end	- virtual end address
 */
ENTRY(arm1026_coherent_kern_range)
	mov	ip, #0
	bic	r0, r0, #CACHE_DLINESIZE - 1
1:
#ifndef CONFIG_CPU_DCACHE_DISABLE
	mcr	p15, 0, r0, c7, c10, 1		@ clean D entry
#endif
#ifndef CONFIG_CPU_ICACHE_DISABLE
	mcr	p15, 0, r0, c7, c5, 1		@ invalidate I entry
#endif
	add	r0, r0, #CACHE_DLINESIZE
	cmp	r0, r1
	blo	1b
	mcr	p15, 0, ip, c7, c10, 4		@ drain WB
	mov	pc, lr

/*
 *	flush_kern_dcache_page(void *page)
 *
 *	Ensure no D cache aliasing occurs, either with itself or
 *	the I cache
 *
 *	- page	- page aligned address
 */
ENTRY(arm1026_flush_kern_dcache_page)
	mov	ip, #0
#ifndef CONFIG_CPU_DCACHE_DISABLE
	add	r1, r0, #PAGE_SZ
1:	mcr	p15, 0, r0, c7, c14, 1		@ clean+invalidate D entry
	add	r0, r0, #CACHE_DLINESIZE
	cmp	r0, r1
	blo	1b
#endif
	mcr	p15, 0, ip, c7, c10, 4		@ drain WB
	mov	pc, lr

/*
 *	dma_inv_range(start, end)
 *
 *	Invalidate (discard) the specified virtual address range.
 *	May not write back any entries.  If 'start' or 'end'
 *	are not cache line aligned, those lines must be written
 *	back.
 *
 *	- start	- virtual start address
 *	- end	- virtual end address
 *
 * (same as v4wb)
 */
ENTRY(arm1026_dma_inv_range)
	mov	ip, #0
#ifndef CONFIG_CPU_DCACHE_DISABLE
	tst	r0, #CACHE_DLINESIZE - 1
	bic	r0, r0, #CACHE_DLINESIZE - 1
	mcrne	p15, 0, r0, c7, c10, 1		@ clean D entry
	tst	r1, #CACHE_DLINESIZE - 1
	mcrne	p15, 0, r1, c7, c10, 1		@ clean D entry
1:	mcr	p15, 0, r0, c7, c6, 1		@ invalidate D entry
	add	r0, r0, #CACHE_DLINESIZE
	cmp	r0, r1
	blo	1b
#endif
	mcr	p15, 0, ip, c7, c10, 4		@ drain WB
	mov	pc, lr

/*
 *	dma_clean_range(start, end)
 *
 *	Clean the specified virtual address range.
 *
 *	- start	- virtual start address
 *	- end	- virtual end address
 *
 * (same as v4wb)
 */
ENTRY(arm1026_dma_clean_range)
	mov	ip, #0
#ifndef CONFIG_CPU_DCACHE_DISABLE
	bic	r0, r0, #CACHE_DLINESIZE - 1
1:	mcr	p15, 0, r0, c7, c10, 1		@ clean D entry
	add	r0, r0, #CACHE_DLINESIZE
	cmp	r0, r1
	blo	1b
#endif
	mcr	p15, 0, ip, c7, c10, 4		@ drain WB
	mov	pc, lr

/*
 *	dma_flush_range(start, end)
 *
 *	Clean and invalidate the specified virtual address range.
 *
 *	- start	- virtual start address
 *	- end	- virtual end address
 */
ENTRY(arm1026_dma_flush_range)
	mov	ip, #0
#ifndef CONFIG_CPU_DCACHE_DISABLE
	bic	r0, r0, #CACHE_DLINESIZE - 1
1:	mcr	p15, 0, r0, c7, c14, 1		@ clean+invalidate D entry
	add	r0, r0, #CACHE_DLINESIZE
	cmp	r0, r1
	blo	1b
#endif
	mcr	p15, 0, ip, c7, c10, 4		@ drain WB
	mov	pc, lr

ENTRY(arm1026_cache_fns)
	.long	arm1026_flush_kern_cache_all
	.long	arm1026_flush_user_cache_all
	.long	arm1026_flush_user_cache_range
	.long	arm1026_coherent_kern_range
	.long	arm1026_flush_kern_dcache_page
	.long	arm1026_dma_inv_range
	.long	arm1026_dma_clean_range
	.long	arm1026_dma_flush_range

	.align	5
ENTRY(cpu_arm1026_dcache_clean_area)
#ifndef CONFIG_CPU_DCACHE_DISABLE
	mov	ip, #0
1:	mcr	p15, 0, r0, c7, c10, 1		@ clean D entry
	add	r0, r0, #CACHE_DLINESIZE
	subs	r1, r1, #CACHE_DLINESIZE
	bhi	1b
#endif
	mov	pc, lr

/* =============================== PageTable ============================== */

/*
 * cpu_arm1026_switch_mm(pgd)
 *
 * Set the translation base pointer to be as described by pgd.
 *
 * pgd: new page tables
 */
	.align	5
ENTRY(cpu_arm1026_switch_mm)
	mov	r1, #0
#ifndef CONFIG_CPU_DCACHE_DISABLE
1:	mrc	p15, 0, r15, c7, c14, 3		@ test, clean, invalidate
	bne	1b
#endif
#ifndef CONFIG_CPU_ICACHE_DISABLE
	mcr	p15, 0, r1, c7, c5, 0		@ invalidate I cache
#endif
	mcr	p15, 0, r1, c7, c10, 4		@ drain WB
	mov	pc, lr
        

	__INIT

	.type	__arm1026_setup, #function
__arm1026_setup:
	mov	r0, #0
	mcr	p15, 0, r0, c7, c7		@ invalidate I,D caches on v4
	mcr	p15, 0, r0, c7, c10, 4		@ drain write buffer on v4
#ifdef CONFIG_CPU_DCACHE_WRITETHROUGH
	mov	r0, #4				@ explicitly disable writeback
	mcr	p15, 7, r0, c15, c0, 0
#endif
	mrc	p15, 0, r0, c1, c0		@ get control register v4
/*
 * Clear out 'unwanted' bits (then put them in if we need them)
 */
	bic	r0, r0, #0x1e00 		@ ...i??r.........
	bic	r0, r0, #0x000e 		@ ............wca.
/*
 * Turn on what we want
 */
#ifdef CONFIG_CPU_MXU_ENABLE
						@ ..........DP...M
	orr	r0, r0, #0x0031			@ if we need MMU on for
						@ d-cache, it would be
#else						@ enabled.
	orr	r0, r0, #0x0030
#endif
	orr	r0, r0, #0x2100 		@ ..V....S........

#ifdef CONFIG_CPU_CACHE_ROUND_ROBIN
	orr	r0, r0, #0x4000 		@ .R..............
#endif
#ifndef CONFIG_CPU_BPREDICT_DISABLE
	orr	r0, r0, #0x0800 		@ ....Z...........
#endif
#ifndef CONFIG_CPU_DCACHE_DISABLE
	orr	r0, r0, #0x0004 		@ .............C..
#endif
#ifndef CONFIG_CPU_ICACHE_DISABLE
	orr	r0, r0, #0x1000 		@ ...I............
#endif
	mov	pc, lr
	.size	__arm1026_setup, . - __arm1026_setup

	__INITDATA

/*
 * Purpose : Function pointers used to access above functions - all calls
 *	     come through these
 */
	.type	arm1026_processor_functions, #object
arm1026_processor_functions:
	.word	v5t_early_abort
	.word	cpu_arm1026_proc_init
	.word	cpu_arm1026_proc_fin
	.word	cpu_arm1026_reset
	.word	cpu_arm1026_do_idle
	.word	cpu_arm1026_dcache_clean_area
	.word	cpu_arm1026_switch_mm
	.size	arm1026_processor_functions, . - arm1026_processor_functions

	.section .rodata

	.type	cpu_arch_name, #object
cpu_arch_name:
	.asciz	"armv5tej"
	.size	cpu_arch_name, . - cpu_arch_name

	.type	cpu_elf_name, #object
cpu_elf_name:
	.asciz	"v5"
	.size	cpu_elf_name, . - cpu_elf_name
	.align

	.type	cpu_arm1026_name, #object
cpu_arm1026_name:
	.ascii	"ARM1026EJ-S"
#ifndef CONFIG_CPU_ICACHE_DISABLE
	.ascii	"i"
#endif
#ifndef CONFIG_CPU_DCACHE_DISABLE
	.ascii	"d"
#ifdef CONFIG_CPU_DCACHE_WRITETHROUGH
	.ascii	"(wt)"
#else
	.ascii	"(wb)"
#endif
#endif
#ifndef CONFIG_CPU_BPREDICT_DISABLE
	.ascii	"B"
#endif
#ifdef CONFIG_CPU_CACHE_ROUND_ROBIN
	.ascii	"RR"
#endif
	.ascii	"\0"
	.size	cpu_arm1026_name, . - cpu_arm1026_name

	.align

	.section ".proc.info", #alloc, #execinstr

	.type	__arm1026_proc_info,#object
__arm1026_proc_info:
	.long	0x4106a260			@ ARM 1026EJ-S (v5TEJ)
	.long	0xff0ffff0
	.long	0x00000c12			@ mmuflags
	b	__arm1026_setup
	.long	cpu_arch_name
	.long	cpu_elf_name
	.long	HWCAP_SWP | HWCAP_HALF | HWCAP_THUMB | HWCAP_FAST_MULT
	.long	cpu_arm1026_name
	.long	arm1026_processor_functions
	.long	arm1026_cache_fns
	.size	__arm1026_proc_info, . - __arm1026_proc_info
