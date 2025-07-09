#!/usr/bin/env sh
OS_VERSION=$(echo "$BALENA_HOST_OS_VERSION" | cut -d " " -f 2)
echo "OS Version is $OS_VERSION"

# NOTE: some modules need to be loaded in a specific order
# if that's the case, replace the loop below with a list of
# `insmod $mod_dir/<module>.ko` commands in the right order
for file in "$MOD_PATH"/*.ko; do
	if lsmod | grep -q edatec_panel_regulator; then
		rmmod edatec_panel_regulator
	fi
	if lsmod | grep -q panel_ilitek_ili9881c; then
		rmmod panel_ilitek_ili9881c
	fi
	echo Loading module from "$file"
	insmod "$file"
done


#for mod in /opt/lib/modules/$OS_VERSION/*.ko; do
#  	echo "loading module $mod ..."
#  	insmod "$mod"
#done

#echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
#echo "Searching for the built module in vc4-kms-dsi-rzw-t101p136cq-cm5.dtbo ..."
#find / | grep "vc4-kms-dsi-rzw-t101p136cq-cm5.dtbo"
#echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
#echo "ls $MOD_PATH"
#ls "$MOD_PATH"
#echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
#echo "ls /sys/kernel/config/device-tree/overlays/"
#ls /sys/kernel/config/device-tree/overlays/

mkdir -p /sys/kernel/config/device-tree/overlays/hmi2002/
echo $$MOD_PATH/vc4-kms-dsi-rzw-t101p136cq-cm5.dtbo > /sys/kernel/config/device-tree/overlays/hmi2002/
