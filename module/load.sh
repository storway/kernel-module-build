#!/usr/bin/env sh
OS_VERSION=$(echo "$BALENA_HOST_OS_VERSION" | cut -d " " -f 2)
echo "OS Version is $OS_VERSION"

# NOTE: some modules need to be loaded in a specific order
# if that's the case, replace the loop below with a list of
# `insmod $mod_dir/<module>.ko` commands in the right order
# for file in "$MOD_PATH"/*.ko; do
# 	if lsmod | grep -q edatec_panel_regulator; then
# 		rmmod edatec_panel_regulator
# 	fi
# 	if lsmod | grep -q panel_ilitek_ili9881c; then
# 		rmmod panel_ilitek_ili9881c
# 	fi
# 	echo Loading module from "$file"
# 	insmod "$file"
# done

if lsmod | grep -q panel-ilitek-ili9881c; then
	rmmod panel-ilitek-ili9881c
fi
#file="$MOD_PATH"/panel-ilitek-ili9881c.ko
#echo Loading module from "$file"
#insmod "$file"

if lsmod | grep -q edatec-panel-regulator; then
	rmmod edatec-panel-regulator
fi
#file="$MOD_PATH"/edatec-panel-regulator.ko
#echo Loading module from "$file"
#insmod "$file"

echo "[INFO] Loading panel driver module..."
#depmod -a
#modprobe panel-ilitek-ili9881c
insmod $MOD_PATH/panel-ilitek-ili9881c.ko

echo "[INFO] Loading regulator driver module..."
#depmod -a
#modprobe edatec-panel-regulator

#sudo modprobe regmap-i2c
insmod $MOD_PATH/edatec-panel-regulator.ko

#for mod in /opt/lib/modules/$OS_VERSION/*.ko; do
#  	echo "loading module $mod ..."
#  	insmod "$mod"
#done

# # DEBUGGING
# echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
# echo "Searching for the built module in vc4-kms-dsi-rzw-t101p136cq-cm5.dtbo ..."
# find / | grep "vc4-kms-dsi-rzw-t101p136cq-cm5.dtbo"
# echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
# echo "ls $MOD_PATH"
# ls "$MOD_PATH"
# echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"


#echo "ls /sys/kernel/config/device-tree/overlays/"
#ls /sys/kernel/config/device-tree/overlays/

#mkdir -p /sys/kernel/config/device-tree/overlays/hmi2002/
#echo $$MOD_PATH/vc4-kms-dsi-rzw-t101p136cq-cm5.dtbo > /sys/kernel/config/device-tree/overlays/hmi2002/


# mount configfs if needed
if ! mountpoint -q /sys/kernel/config; then
  mount -t configfs none /sys/kernel/config
fi

OVERLAY_NAME=hmi2002
DTBO_PATH=$(ls $MOD_PATH/*.dtbo)

echo "Found overlay $OVERLAY_NAME in $DTBO_PATH ."

# Create the overlay-configfs folder
mkdir -p /sys/kernel/config/device-tree/overlays/$OVERLAY_NAME

# Push the dtbo blob in
cat $DTBO_PATH \
  > /sys/kernel/config/device-tree/overlays/$OVERLAY_NAME/dtbo

echo "Overlay $OVERLAY_NAME loaded"

if [ -d /sys/kernel/config/device-tree/overlays/hmi2002 ]; then
    echo "Overlay hmi2002 correctly loaded" > /dev/kmsg
#else
#    echo "Overlay hmi2002 not loaded!" > /dev/kmsg
fi


# A background sleep allows to handle signals
# exec /bin/sh -c "trap : TERM INT; sleep 9999999999d & wait"