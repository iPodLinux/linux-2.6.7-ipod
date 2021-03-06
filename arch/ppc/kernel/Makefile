#
# Makefile for the linux kernel.
#

ifdef CONFIG_PPC64BRIDGE
EXTRA_AFLAGS		:= -Wa,-mppc64bridge
endif
ifdef CONFIG_4xx
EXTRA_AFLAGS		:= -Wa,-m405
endif

extra-$(CONFIG_PPC_STD_MMU)	:= head.o
extra-$(CONFIG_40x)		:= head_4xx.o
extra-$(CONFIG_44x)		:= head_44x.o
extra-$(CONFIG_8xx)		:= head_8xx.o
extra-$(CONFIG_6xx)		+= idle_6xx.o
extra-$(CONFIG_POWER4)		+= idle_power4.o
extra-y				+= vmlinux.lds.s

obj-y				:= entry.o traps.o irq.o idle.o time.o misc.o \
					process.o signal.o ptrace.o align.o \
					semaphore.o syscalls.o setup.o \
					cputable.o ppc_htab.o
obj-$(CONFIG_6xx)		+= l2cr.o cpu_setup_6xx.o
obj-$(CONFIG_POWER4)		+= cpu_setup_power4.o
obj-$(CONFIG_MODULES)		+= module.o ppc_ksyms.o
obj-$(CONFIG_NOT_COHERENT_CACHE)	+= dma-mapping.o
obj-$(CONFIG_PCI)		+= pci.o
obj-$(CONFIG_KGDB)		+= ppc-stub.o
obj-$(CONFIG_SMP)		+= smp.o smp-tbsync.o
obj-$(CONFIG_TAU)		+= temp.o
obj-$(CONFIG_ALTIVEC)		+= vecemu.o vector.o

ifdef CONFIG_MATH_EMULATION
obj-$(CONFIG_8xx)		+= softemu8xx.o
endif

