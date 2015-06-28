#ifndef _ASM_PGALLOC_H
#define _ASM_PGALLOC_H

#include <linux/gfp.h>
#include <linux/mm.h>
#include <linux/threads.h>
#include <asm/processor.h>
#include <asm/fixmap.h>

#include <asm/pgtable.h>
#include <asm/cache.h>

/* Allocate the top level pgd (page directory)
 *
 * Here (for 64 bit kernels) we implement a Hybrid L2/L3 scheme: we
 * allocate the first pmd adjacent to the pgd.  This means that we can
 * subtract a constant offset to get to it.  The pmd and pgd sizes are
 * arranged so that a single pmd covers 4GB (giving a full LP64
 * process access to 8TB) so our lookups are effectively L2 for the
 * first 4GB of the kernel (i.e. for all ILP32 processes and all the
 * kernel for machines with under 4GB of memory) */
static inline pgd_t *pgd_alloc(struct mm_struct *mm)
{
	pgd_t *pgd = (pgd_t *)__get_free_pages(GFP_KERNEL|GFP_DMA,
					       PGD_ALLOC_ORDER);
	pgd_t *actual_pgd = pgd;

	if (likely(pgd != NULL)) {
		memset(pgd, 0, PAGE_SIZE<<PGD_ALLOC_ORDER);
#ifdef __LP64__
		actual_pgd += PTRS_PER_PGD;
		/* Populate first pmd with allocated memory.  We mark it
		 * with _PAGE_GATEWAY as a signal to the system that this
		 * pmd entry may not be cleared. */
		pgd_val(*actual_pgd) = (_PAGE_TABLE | _PAGE_GATEWAY) + 
			(__u32)__pa((unsigned long)pgd);
		/* The first pmd entry also is marked with _PAGE_GATEWAY as
		 * a signal that this pmd may not be freed */
		pgd_val(*pgd) = _PAGE_GATEWAY;
#endif
	}
	return actual_pgd;
}

static inline void pgd_free(pgd_t *pgd)
{
#ifdef __LP64__
	pgd -= PTRS_PER_PGD;
#endif
	free_pages((unsigned long)pgd, PGD_ALLOC_ORDER);
}

#if PT_NLEVELS == 3

/* Three Level Page Table Support for pmd's */

static inline void pgd_populate(struct mm_struct *mm, pgd_t *pgd, pmd_t *pmd)
{
	pgd_val(*pgd) = _PAGE_TABLE + (__u32)__pa((unsigned long)pmd);
}

/* NOTE: pmd must be in ZONE_DMA (<4GB) so the pgd pointer can be
 * housed in 32 bits */
static inline pmd_t *pmd_alloc_one(struct mm_struct *mm, unsigned long address)
{
	pmd_t *pmd = (pmd_t *)__get_free_pages(GFP_KERNEL|__GFP_REPEAT|GFP_DMA,
					       PMD_ORDER);
	if (pmd)
		memset(pmd, 0, PAGE_SIZE<<PMD_ORDER);
	return pmd;
}

static inline void pmd_free(pmd_t *pmd)
{
#ifdef __LP64__
	if(pmd_val(*pmd) & _PAGE_GATEWAY)
		/* This is the permanent pmd attached to the pgd;
		 * cannot free it */
		return;
#endif
	free_pages((unsigned long)pmd, PMD_ORDER);
}

#else

/* Two Level Page Table Support for pmd's */

/*
 * allocating and freeing a pmd is trivial: the 1-entry pmd is
 * inside the pgd, so has no extra memory associated with it.
 */

#define pmd_alloc_one(mm, addr)		({ BUG(); ((pmd_t *)2); })
#define pmd_free(x)			do { } while (0)
#define pgd_populate(mm, pmd, pte)	BUG()

#endif

static inline void
pmd_populate_kernel(struct mm_struct *mm, pmd_t *pmd, pte_t *pte)
{
#ifdef __LP64__
	/* preserve the gateway marker if this is the beginning of
	 * the permanent pmd */
	if(pmd_val(*pmd) & _PAGE_GATEWAY)
		pmd_val(*pmd) = (_PAGE_TABLE | _PAGE_GATEWAY)
			+ (__u32)__pa((unsigned long)pte);
	else
#endif
		pmd_val(*pmd) = _PAGE_TABLE + (__u32)__pa((unsigned long)pte);
}

#define pmd_populate(mm, pmd, pte_page) \
	pmd_populate_kernel(mm, pmd, page_address(pte_page))

/* NOTE: pte must be in ZONE_DMA (<4GB) so that the pmd pointer
 * can be housed in 32 bits */
static inline struct page *
pte_alloc_one(struct mm_struct *mm, unsigned long address)
{
	struct page *page = alloc_page(GFP_KERNEL|__GFP_REPEAT|GFP_DMA);
	if (likely(page != NULL))
		clear_page(page_address(page));
	return page;
}

static inline pte_t *
pte_alloc_one_kernel(struct mm_struct *mm, unsigned long addr)
{
	pte_t *pte = (pte_t *)__get_free_page(GFP_KERNEL|__GFP_REPEAT|GFP_DMA);
	if (likely(pte != NULL))
		clear_page(pte);
	return pte;
}

static inline void pte_free_kernel(pte_t *pte)
{
	free_page((unsigned long)pte);
}

#define pte_free(page)	pte_free_kernel(page_address(page))

extern int do_check_pgt_cache(int, int);
#define check_pgt_cache()	do { } while (0)

#endif