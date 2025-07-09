#!/usr/bin/env sh

#if dmesg | grep -q "ilite"; then
#	echo "Module correctly loaded"
#else
#	echo "Something went wrong!"
#	exit 1
#fi

echo "Checking if the module is loaded..."
dmesg | grep -q "dsi"

echo " lsmod | grep edatec"
lsmod | grep edatec

echo "ls /sys/kernel/config/device-tree/overlays"
ls /sys/kernel/config/device-tree/overlays

# A background sleep allows to handle signals
exec /bin/sh -c "trap : TERM INT; sleep 9999999999d & wait"
