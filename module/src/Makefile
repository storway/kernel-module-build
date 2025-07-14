KERNEL_TREE_PATH?=/lib/modules/$(shell uname -r)/build
EXTRA_CFLAGS="-DDEBUG"

obj-m := edatec-panel-regulator.o panel-ilitek-ili9881c.o

#edatec-panel-regulator-objs := edatec-panel-regulator.o
#panel-ilitek-ili9881c-objs := panel-ilitek-ili9881c.o

all:
	make -C $(KERNEL_TREE_PATH) M=$(PWD) modules

clean:
	make -C $(KERNEL_TREE_PATH) M=$(PWD) clean

.PHONY: all clean
