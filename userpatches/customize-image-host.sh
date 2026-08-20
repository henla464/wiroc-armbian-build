#!/bin/bash
# Runs on the build HOST (config variables are in scope here) before the chroot
# image customization. Pass the selected WiRoc variant + hardware version into
# the image so that customize-image.sh / install-wiroc.sh (which run inside the
# chroot and only receive RELEASE/LINUXFAMILY/BOARD/BUILD_DESKTOP/ARCH) can use
# them.

mkdir -p "${SDCARD}/tmp"
echo "${WIROC_VARIANT:-esp32}" > "${SDCARD}/tmp/wiroc-variant"
echo "${WIROC_HW_VERSION:-v8Rev2}" > "${SDCARD}/tmp/wiroc-hwversion"
echo "${WIROC_PYTHON_VERSION:-1.46}" > "${SDCARD}/tmp/wiroc-pythonversion"
