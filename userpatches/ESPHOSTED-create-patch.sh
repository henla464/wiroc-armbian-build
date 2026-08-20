#!/bin/bash

ESPHOSTED_HOSTDIR="/home/henla464/Documents/WiRoc/ESPHosted/esp-hosted/esp_hosted_ng/host"
KERNEL_DESTINATIONDIR="/tmp/linux-6.12/drivers/net/wireless"

mkdir -p $KERNEL_DESTINATIONDIR/espressif
mkdir -p $KERNEL_DESTINATIONDIR/espressif/spi
mkdir -p $KERNEL_DESTINATIONDIR/espressif/include

cp $ESPHOSTED_HOSTDIR/Makefile $KERNEL_DESTINATIONDIR/espressif/
cp $ESPHOSTED_HOSTDIR/esp_bt.c $KERNEL_DESTINATIONDIR/espressif/
cp $ESPHOSTED_HOSTDIR/esp_cfg80211.c $KERNEL_DESTINATIONDIR/espressif/
cp $ESPHOSTED_HOSTDIR/esp_cmd.c $KERNEL_DESTINATIONDIR/espressif/
cp $ESPHOSTED_HOSTDIR/esp_debugfs.c $KERNEL_DESTINATIONDIR/espressif/
cp $ESPHOSTED_HOSTDIR/esp_log.c $KERNEL_DESTINATIONDIR/espressif/
cp $ESPHOSTED_HOSTDIR/esp_stats.c $KERNEL_DESTINATIONDIR/espressif/
cp $ESPHOSTED_HOSTDIR/esp_utils.c $KERNEL_DESTINATIONDIR/espressif/
cp $ESPHOSTED_HOSTDIR/include/adapter.h $KERNEL_DESTINATIONDIR/espressif/include/
cp $ESPHOSTED_HOSTDIR/include/esp.h $KERNEL_DESTINATIONDIR/espressif/include/
cp $ESPHOSTED_HOSTDIR/include/esp_api.h $KERNEL_DESTINATIONDIR/espressif/include/
cp $ESPHOSTED_HOSTDIR/include/esp_bt_api.h $KERNEL_DESTINATIONDIR/espressif/include/
cp $ESPHOSTED_HOSTDIR/include/esp_cfg80211.h $KERNEL_DESTINATIONDIR/espressif/include/
cp $ESPHOSTED_HOSTDIR/include/esp_cmd.h $KERNEL_DESTINATIONDIR/espressif/include/
cp $ESPHOSTED_HOSTDIR/include/esp_fw_version.h $KERNEL_DESTINATIONDIR/espressif/include/
cp $ESPHOSTED_HOSTDIR/include/esp_if.h $KERNEL_DESTINATIONDIR/espressif/include/
cp $ESPHOSTED_HOSTDIR/include/esp_kernel_port.h $KERNEL_DESTINATIONDIR/espressif/include/
cp $ESPHOSTED_HOSTDIR/include/esp_stats.h $KERNEL_DESTINATIONDIR/espressif/include/
cp $ESPHOSTED_HOSTDIR/include/esp_utils.h $KERNEL_DESTINATIONDIR/espressif/include/
cp $ESPHOSTED_HOSTDIR/include/utils.h $KERNEL_DESTINATIONDIR/espressif/include/
cp $ESPHOSTED_HOSTDIR/main.c $KERNEL_DESTINATIONDIR/espressif/
cp $ESPHOSTED_HOSTDIR/spi/esp_spi.c $KERNEL_DESTINATIONDIR/espressif/spi/
cp $ESPHOSTED_HOSTDIR/spi/esp_spi.h $KERNEL_DESTINATIONDIR/espressif/spi/

# replace the content of the Makefile
cat <<'EOF' > "$KERNEL_DESTINATIONDIR/espressif/Makefile"
# List of all object files for this driver
esphosted-objs := main.o spi/esp_spi.o esp_bt.o esp_cmd.o esp_utils.o esp_cfg80211.o esp_stats.o esp_debugfs.o esp_log.o

# Name of the module object to create
esp32_spi-y := $(esphosted-objs)

# Conditional compilation: built-in (y) or module (m) via CONFIG_ESPHOSTED
obj-$(CONFIG_ESPRESSIF_ESPHOSTED) := esp32_spi.o

# Find the .h files
ccflags-y += -I$(src)/include -I$(src)/spi

# Per-file flags: define DEBUG only for esp_log.o
CFLAGS_esp_log.o = -DDEBUG
EOF

# Add KConfig
cat <<'EOF' > "$KERNEL_DESTINATIONDIR/espressif/Kconfig"
# SPDX-License-Identifier: GPL-2.0-only
config ESPRESSIF_ESPHOSTED
	tristate "ESPHosted driver for Wifi and BT"
	help
	  This module provides Wifi and BT driver using a ESP32C5 as coprocessor

	  Say Y or M here to enable this Wifi/BT driver module.
EOF

# change spi/esp_spi.h
# #define HANDSHAKE_PIN           203
# #define SPI_DATA_READY_PIN      142
sed -i 's|^#define[[:space:]]\+HANDSHAKE_PIN.*|#define HANDSHAKE_PIN           203|' $KERNEL_DESTINATIONDIR/espressif/spi/esp_spi.h
sed -i 's|^#define[[:space:]]\+SPI_DATA_READY_PIN.*|#define SPI_DATA_READY_PIN      142|' $KERNEL_DESTINATIONDIR/espressif/spi/esp_spi.h
# change main.c: static int resetpin =  143
sed -i 's|^static[[:space:]]\+int[[:space:]]\+resetpin.*|static int resetpin =  143;|' $KERNEL_DESTINATIONDIR/espressif/main.c

# Manully git add drivers/net/wireless/espressif/
# git diff --cached > esp_hosted.patch
# mv esp_hosted.patch ~/Documents/WiRoc/wiroc-armbian-build/userpatches/kernel/archive/sunxi-6.12



