#
# Makefile for the linux MPC8xx ppc-specific parts of comm processor
#

obj-y			:= commproc.o uart.o

obj-$(CONFIG_FEC_ENET)	+= fec.o
obj-$(CONFIG_SCC_ENET)	+= enet.o
obj-$(CONFIG_UCODE_PATCH) += micropatch.o
obj-$(CONFIG_HTDMSOUND) += cs4218_tdm.o
