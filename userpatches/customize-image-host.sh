#!/bin/bash
# Runs on the build HOST (config variables are in scope here) before the chroot
# image customization. Pass the selected WiRoc variant into the image so that
# customize-image.sh (which runs inside the chroot and only receives
# RELEASE/LINUXFAMILY/BOARD/BUILD_DESKTOP/ARCH) can branch on it.

mkdir -p "${SDCARD}/tmp"
echo "${WIROC_VARIANT:-esp32}" > "${SDCARD}/tmp/wiroc-variant"
