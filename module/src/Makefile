KERNEL_TREE_PATH?=/lib/modules/$(shell uname -r)/build
EXTRA_CFLAGS="-DDEBUG"

obj-m := edatec_panel_regulator.o panel_ilitek_ili9881c.o

edatec_panel_regulator-objs := edatec-panel-regulator.o
panel_ilitek_ili9881c-objs := panel-ilitek-ili9881c.o

all:
	make -C $(KERNEL_TREE_PATH) M=$(PWD) modules

clean:
	make -C $(KERNEL_TREE_PATH) M=$(PWD) clean

.PHONY: all clean
