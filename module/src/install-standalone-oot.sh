#!/bin/bash
# EDATEC HMI2002 drivers and overlays
# Standalone script to TEST the out of tree module load (drivers and overlays) on a Raspberry Pi

set -e

# rpi5:
OVERLAY_NAME="vc4-kms-dsi-rzw-t101p136cq-rpi5-2lane-overlay"
DTBO_PATH="/sys/kernel/config/device-tree/overlays/$OVERLAY_NAME.dtbo"

# rpi4:
# OVERLAY_NAME="vc4-kms-dsi-rzw-t101p136cq-rpi4-2lane-overlay"

# cm5:
# OVERLAY_NAME="vc4-kms-dsi-rzw-t101p136cq-cm5-overlay"

# overlay:
# OVERLAY_NAME="vc4-kms-dsi-rzw-t101p136cq-overlay"

echo "[INFO] Using device tree overlay: $OVERLAY_NAME"

# === CONFIG ===
KERNEL_VERSION=$(uname -r)
MODULE_DIR="/lib/modules/$KERNEL_VERSION/kernel"
SRC_DIR="$(pwd)"

# Determine the logged-in user (non-root)
TARGET_USER=$(logname)
USER_HOME="/home/$TARGET_USER"
#AUTOSTART_DIR="$USER_HOME/.config/autostart"
#BIN_DIR="$USER_HOME/.local/bin"

# === PREP ===
echo "[INFO] Installing build dependencies..."
sudo apt-get update
sudo apt-get install -y build-essential raspberrypi-kernel-headers device-tree-compiler

#remove in advance the overlay is already loaded

if dtoverlay -l | grep -q $OVERLAY_NAME; then
  sudo dtoverlay -R $OVERLAY_NAME
fi

# === COMPILE DRIVERS ===
# Remove default in-tree panel driver if present
if [ -f /lib/modules/$(uname -r)/kernel/drivers/gpu/drm/panel/panel-ilitek-ili9881c.ko.xz ]; then
  echo "[INFO] Removing default panel-ilitek-ili9881c.ko.xz to avoid conflict..."
  sudo rm /lib/modules/$(uname -r)/kernel/drivers/gpu/drm/panel/panel-ilitek-ili9881c.ko.xz
fi
if [ -f /lib/modules/$(uname -r)/kernel/drivers/gpu/drm/panel/panel-ilitek-ili9881c.ko ]; then
  echo "[INFO] Removing default panel-ilitek-ili9881c.ko to avoid conflict..."
  sudo rm /lib/modules/$(uname -r)/kernel/drivers/gpu/drm/panel/panel-ilitek-ili9881c.ko
fi
# Remove default in-tree regulator driver if present
if [ -f /lib/modules/$(uname -r)/kernel/drivers/misc/edatec-panel-regulator.ko ]; then
  echo "[INFO] Removing default edatec-panel-regulator.ko to avoid conflict..."
  sudo rm /lib/modules/$(uname -r)/kernel/drivers/misc/edatec-panel-regulator.ko
fi

if lsmod | grep -q panel-ilitek-ili9881c; then
	sudo rmmod panel-ilitek-ili9881c
fi
if lsmod | grep -q panel_ilitek_ili9881c; then
	sudo rmmod panel_ilitek_ili9881c
fi

if lsmod | grep -q edatec-panel-regulator; then
	sudo rmmod edatec-panel-regulator
fi
if lsmod | grep -q edatec_panel_regulator; then
	sudo rmmod edatec_panel_regulator
fi


echo "[INFO] Building DRM panel driver..."
make -C /lib/modules/$(uname -r)/build M=$SRC_DIR clean
make -C /lib/modules/$(uname -r)/build M=$SRC_DIR modules

#echo "[INFO] Copying drivers to $MODULE_DIR..."
#sudo cp $SRC_DIR/panel-ilitek-ili9881c.ko $MODULE_DIR/drivers/gpu/drm/panel/
#sudo cp $SRC_DIR/edatec-panel-regulator.ko $MODULE_DIR/drivers/misc/

#if [ -f "$DRIVER_DIR/misc/edatec-panel-regulator.c" ]; then
#  echo "[INFO] Building and installing edatec-panel-regulator.ko..."
#  make -C /lib/modules/$(uname -r)/build M=$DRIVER_DIR/misc modules
#  sudo cp $DRIVER_DIR/misc/edatec-panel-regulator.ko $MODULE_DIR/drivers/misc/
#fi

# === Update module dependencies ===
#echo "[INFO] Updating module dependencies..."
#sudo depmod -a

# === LOAD MODULES ===
echo "[INFO] Loading panel driver module..."
#depmod -a
#modprobe panel-ilitek-ili9881c
#sudo insmod $MODULE_DIR/drivers/gpu/drm/panel/panel-ilitek-ili9881c.ko
sudo insmod $SRC_DIR/panel-ilitek-ili9881c.ko


echo "[INFO] Loading regulator driver module..."
#depmod -a
#modprobe edatec-panel-regulator

sudo modprobe regmap-i2c
#sudo insmod $MODULE_DIR/drivers/misc/edatec-panel-regulator.ko
sudo insmod $SRC_DIR/edatec-panel-regulator.ko



# === COMPILE DEVICE TREE OVERLAYS ===
rm -rf $SRC_DIR/*.dtbo

echo "[INFO] Compiling overlays..."
DTBO="$SRC_DIR/$OVERLAY_NAME.dtbo"
DTS="$SRC_DIR/$OVERLAY_NAME.dts"
echo "  - Compiling overlay: sudo dtc -@ -I dts -O dtb -o \"$DTBO\" \"$DTS\""

dtc -@ -I dts -O dtb -o "$DTBO" "$DTS"


#find "$SRC_DIR" -name "*.dts" | while read -r dts; do
#    dtbo="/sys/kernel/config/device-tree/overlays/$(basename "${dts%.dts}").dtbo"
#    echo "  - Compiling $(basename "$dts") -> $(basename "$dtbo")"
#    sudo dtc -@ -I dts -O dtb -o "$dtbo" "$dts"
#done

# sudo dtc -@ -I dts -O dtb -o "/boot/overlays/vc4-kms-dsi-rzw-t101p136cq-rpi5-2lane.dtbo" "./SOURCES/OVERLAY/vc4-kms-dsi-rzw-t101p136cq-rpi5-2lane-overlay.dts" 

#sudp mkdir -p /sys/kernel/config/device-tree/overlays/$OVERLAY_NAME
#sudo cat $DTBO \
#  > /sys/kernel/config/device-tree/overlays/$OVERLAY_NAME/dtbo

echo "sudo dtoverlay $OVERLAY_NAME ..."
#sudo dtoverlay ./"$OVERLAY_NAME".dtbo,interrupt=2
sudo dtoverlay ./"$OVERLAY_NAME".dtbo
#sudo dtoverlay "$OVERLAY_NAME"  # works as well even if without interrupt=2
 


if dtoverlay -l | grep -q $OVERLAY_NAME; then
    echo "Overlay $OVERLAY_NAME loaded"
    #sudo echo "Overlay hmi2002 correctly loaded" > /dev/kmsg
else
    echo "Overlay $OVERLAY_NAME NOT loaded"
    #sudo echo "Overlay hmi2002 not loaded!" > /dev/kmsg
fi

#if [ -d /sys/kernel/config/device-tree/overlays/hmi2002 ]; then
#    echo "Overlay $OVERLAY_NAME loaded"
#    #sudo echo "Overlay hmi2002 correctly loaded" > /dev/kmsg
#else
#    echo "Overlay $OVERLAY_NAME NOT loaded"
#    #sudo echo "Overlay hmi2002 not loaded!" > /dev/kmsg
#fi

# # === SET OVERLAY IN config.txt ===
# echo "[INFO] Updating /boot/firmware/config.txt with overlay: $OVERLAY_NAME"
# sudo sed -i '/^dtoverlay=vc4-kms-dsi-rzw-t101p136cq-/d' /boot/firmware/config.txt
# echo "dtoverlay=${OVERLAY_NAME},interrupt=2" | sudo tee -a /boot/firmware/config.txt > /dev/null
# echo "dtparam=ant2" | sudo tee -a /boot/firmware/config.txt > /dev/null

# # === DISPLAY ROTATION SETUP ===
# echo "[INFO] Setting up persistent display rotation using wlr-randr..."
# sudo -u $TARGET_USER mkdir -p "$AUTOSTART_DIR"
# sudo -u $TARGET_USER mkdir -p "$BIN_DIR"
# 
# # Create rotation script
# sudo tee "$BIN_DIR/force-rotate.sh" > /dev/null << EOF
# #!/bin/bash
# sleep 2
# wlr-randr --output DSI-2 --transform 90
# EOF
# 
# sudo chmod +x "$BIN_DIR/force-rotate.sh"
# sudo chown $TARGET_USER:$TARGET_USER "$BIN_DIR/force-rotate.sh"
# 
# # Create autostart desktop entry
# sudo tee "$AUTOSTART_DIR/rotate-dsi.desktop" > /dev/null << EOF
# [Desktop Entry]
# Type=Application
# Name=Rotate DSI Left
# Exec=$BIN_DIR/force-rotate.sh
# X-GNOME-Autostart-enabled=true
# EOF
# 
# sudo chown $TARGET_USER:$TARGET_USER "$AUTOSTART_DIR/rotate-dsi.desktop"
# 
# # Udev rule for TS rotate
# echo "[INFO] Setting up Goodix touchscreen rotation..."
# 
# sudo mkdir -p /etc/libinput
# sudo tee /etc/libinput/local-overrides.quirks > /dev/null << 'EOF'
# [Goodix Touchscreen Rotation]
# MatchName=10-0014 Goodix Capacitive TouchScreen
# AttrCalibrationMatrix=0 -1 1 1 0 0
# EOF


# === DONE ===
echo "[SUCCESS] Driver and overlay script executed."
#echo "[SUCCESS] Driver and overlay installed for '$CONFIG'. Screen rotation set."
#echo "Rebooting..."
#sudo reboot
