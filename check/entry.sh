#!/usr/bin/env sh

#if dmesg | grep -q "ilite"; then
#	echo "Module correctly loaded"
#else
#	echo "Something went wrong!"
#	exit 1
#fi

if lsmod | grep -q "edatec_panel_regulator"; then
	echo "Edatec regulator correctly loaded"
else
	echo "Edatec regulator not loaded!"
	exit 1
fi

if lsmod | grep -q "panel_ilitek_ili9881c"; then
    echo "Panel driver correctly loaded"
else
    echo "Panel driver not loaded!"
    exit 1
fi

if dmesg | grep -q "Overlay hmi2002 correctly loaded" ; then
    echo "Overlay hmi2002 correctly loaded"
else
    echo "Overlay hmi2002 not loaded!"
    exit 1
fi


# DEBUGGING
# echo "Checking if the module is loaded..."
# dmesg | grep -q "dsi"
# 
# echo " lsmod | grep edatec_panel_regulator"
# lsmod | grep edatec_panel_regulator
# 
# echo " lsmod | grep panel_ilitek_ili9881c"
# lsmod | grep panel_ilitek_ili9881c
# 
# echo "ls /sys/kernel/config/device-tree/overlays"
# ls /sys/kernel/config/device-tree/overlays

# A background sleep allows to handle signals
exec /bin/sh -c "trap : TERM INT; sleep 9999999999d & wait"
