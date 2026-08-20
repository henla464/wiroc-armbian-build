#!/bin/bash
#
# install-wiroc.sh — bake the WiRoc application stack + system tweaks into the
# image at build time.
#
# Runs NON-INTERACTIVELY inside the image chroot (as root), invoked by
# customize-image.sh. Network and the apikey are available at build time.
#
# This is a direct port of install.sh (the old first-boot installer), with the
# following differences:
#   * non-interactive (values come from /root/settings.yaml + /root/apikey.txt)
#   * the 'chip' user is pre-created (locked) here, so first-boot only sets a password
#   * systemd units are enabled with --no-reload (no running systemd in chroot)
#   * the armbian-config --cmd SY203/UNAT03/SY207 calls are replaced by their
#     direct equivalents (apt-mark hold / disable unattended-upgrades / stable repo)
#   * the /boot/armbianEnv.txt overlay section is DROPPED (customize-image.sh owns it)

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
export APT_LISTCHANGES_FRONTEND=none

# This parses yaml files and outputs rows on the format
# variable="value"
# group_varname="value2"
# use it with "eval $(parse_yaml sample.yml)"
function parse_yaml {
   local prefix="${2:-}"
   local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
   sed -ne "s|^\($s\):|\1|" \
        -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
   awk -F$fs '{
      indent = length($1)/2;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]}}
      if (length($3) > 0) {
         vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
         printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
      }
   }'
}

log() { echo -e "\n\033[1m$*\033[0m"; }

log "install-wiroc.sh: updating apt package lists"
apt-get update

###################################
# Read settings + apikey from /root
###################################
SETTINGSFILE=/root/settings.yaml
if [[ ! -f "$SETTINGSFILE" ]]; then
    echo "FATAL: /root/settings.yaml not found" >&2
    exit 1
fi
eval "$(parse_yaml "$SETTINGSFILE")"

# Allow the hardware version to be chosen at compile time via the build config
# variable WIROC_HW_VERSION (written into the chroot by customize-image-host.sh).
# Fall back to the value in settings.yaml when it isn't set.
WIROC_HW_VERSION_FILE=/tmp/wiroc-hwversion
if [[ -f "$WIROC_HW_VERSION_FILE" ]]; then
    WIROC_HW_VERSION_OVERRIDE="$(cat "$WIROC_HW_VERSION_FILE")"
    if [[ -n "$WIROC_HW_VERSION_OVERRIDE" && "$WIROC_HW_VERSION_OVERRIDE" != "${WiRocHWVersion}" ]]; then
        echo "Overriding WiRoc HW version: ${WiRocHWVersion} -> ${WIROC_HW_VERSION_OVERRIDE} (from WIROC_HW_VERSION)"
        WiRocHWVersion="$WIROC_HW_VERSION_OVERRIDE"
    fi
fi

# Allow the WiRoc-Python-2 version to be chosen at compile time via the build
# config variable WIROC_PYTHON_VERSION (written into the chroot by
# customize-image-host.sh). Fall back to the value in settings.yaml when unset.
WIROC_PYTHON_VERSION_FILE=/tmp/wiroc-pythonversion
if [[ -f "$WIROC_PYTHON_VERSION_FILE" ]]; then
    WIROC_PYTHON_VERSION_OVERRIDE="$(cat "$WIROC_PYTHON_VERSION_FILE")"
    if [[ -n "$WIROC_PYTHON_VERSION_OVERRIDE" && "$WIROC_PYTHON_VERSION_OVERRIDE" != "${WiRocPythonVersion}" ]]; then
        echo "Overriding WiRoc Python version: ${WiRocPythonVersion} -> ${WIROC_PYTHON_VERSION_OVERRIDE} (from WIROC_PYTHON_VERSION)"
        WiRocPythonVersion="$WIROC_PYTHON_VERSION_OVERRIDE"
    fi
fi

echo "WiRoc Python 2 version: ${WiRocPythonVersion:-}"
echo "WiRoc BLE API version:   ${WiRocBLEAPIVersion:-}"
echo "WiRoc HW version:        ${WiRocHWVersion:-}"

if [[ -z "${WiRocPythonVersion:-}" || -z "${WiRocBLEAPIVersion:-}" || -z "${WiRocHWVersion:-}" ]]; then
    echo "FATAL: settings.yaml is missing WiRocPythonVersion / WiRocBLEAPIVersion / WiRocHWVersion" >&2
    exit 1
fi

# Reflect the resolved hardware + python versions in the /root/settings.yaml that
# was baked into the image, so they match the values used for the install (and
# written to /home/chip/settings.yaml below).
if [[ -f "$SETTINGSFILE" ]]; then
    sed -i "s/^WiRocHWVersion:.*/WiRocHWVersion: ${WiRocHWVersion}/" "$SETTINGSFILE"
    sed -i "s/^WiRocPythonVersion:.*/WiRocPythonVersion: ${WiRocPythonVersion}/" "$SETTINGSFILE"
fi

APIKEYFILE=/root/apikey.txt
if [[ ! -f "$APIKEYFILE" ]]; then
    echo "FATAL: /root/apikey.txt not found" >&2
    exit 1
fi

###################################
# Pre-create the 'chip' user (locked, no default password — EU RED 2022/30).
# The WiRoc software hardcodes /home/chip, so it must exist at build time.
###################################
log "Pre-creating 'chip' user (locked)"
if ! id chip >/dev/null 2>&1; then
    useradd -m -s /bin/bash chip
else
    mkdir -p /home/chip
    usermod -s /bin/bash chip 2>/dev/null || true
fi
passwd -l chip >/dev/null 2>&1 || true
for g in sudo netdev audio video disk tty users games dialout plugdev input bluetooth systemd-journal ssh render; do
    usermod -aG "$g" chip 2>/dev/null || true
done

###################################
# Utilities / firmware
###################################
log "Installing utilities and firmware"
apt-get install -y net-tools i2c-tools zip libsqlite3-dev sqlite3 firmware-ath9k-htc

# Enable IP forwarding for wifi mesh and tailscale
cat > /etc/sysctl.d/99-ipforward.conf <<EOF
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOF
sysctl --system >/dev/null 2>&1 || true

###################################
# Bluetooth stack + python tooling
###################################
log "Installing bluetooth stack"
apt-get install -y bluetooth bluez libbluetooth-dev libudev-dev python3-dbus

log "Installing python tooling used by installers"
apt-get install -y python3-venv python3-requests python3-yaml \
    libdbus-1-dev libcairo2-dev python3-dev libgirepository1.0-dev \
    git cython3 python3-build virtualenv libjpeg-dev

###################################
# Relink dbus bindings (for BLE). Debian installs
# _dbus_bindings.cpython-<abi>-arm-linux-gnueabihf.so; some BLE code looks for
# the un-suffixed _dbus_bindings.so. Use python3-config to derive the ABI
# suffix instead of hardcoding cpython-312.
###################################
log "Relinking dbus bindings"
DBUS_SUFFIX="$(python3-config --extension-suffix)"   # e.g. .cpython-313-arm-linux-gnueabihf.so
for base in _dbus_bindings _dbus_glib_bindings; do
    src="/usr/lib/python3/dist-packages/${base}${DBUS_SUFFIX}"
    if [[ -e "$src" ]]; then
        ln -sf "$src" "/usr/lib/python3/dist-packages/${base}.so"
    else
        echo "WARN: ${base}${DBUS_SUFFIX} not found; skipping relink"
    fi
done

###################################
# Write settings.yaml + apikey into /home/chip
###################################
log "Writing /home/chip/settings.yaml + apikey.txt"
cp -f /root/apikey.txt /home/chip/apikey.txt
cat > /home/chip/settings.yaml <<EOF
WiRocDeviceName: WiRoc Device
WiRocPythonVersion: ${WiRocPythonVersion}
WiRocBLEAPIVersion: ${WiRocBLEAPIVersion}
WiRocHWVersion: ${WiRocHWVersion}
EOF

###################################
# WiRoc-BLE-API
###################################
log "Installing WiRoc-BLE-API ${WiRocBLEAPIVersion}"
cd /home/chip
wget -q -O installWiRocBLEAPI.py https://raw.githubusercontent.com/henla464/WiRoc-BLE-API/master/installWiRocBLEAPI.py
chmod ugo+x installWiRocBLEAPI.py
./installWiRocBLEAPI.py "$WiRocBLEAPIVersion" NEW

cd WiRoc-BLE-API
python3 -m venv env
env/bin/pip install -r requirements.txt
cd /home/chip

wget -q -O /etc/systemd/system/WiRocBLEAPI.service https://raw.githubusercontent.com/henla464/WiRoc-StartupScripts/master/WiRocBLEAPI.service
systemctl --no-reload enable WiRocBLEAPI.service

###################################
# reedsolomon (built from source, cythonized)
###################################
log "Building reedsolomon"
rm -rf reedsolomon
git clone https://github.com/tomerfiliba-org/reedsolomon.git
cd reedsolomon
python3 -sBm build --config-setting="--build-option=--cythonize"
export DEB_PYTHON_INSTALL_LAYOUT=deb_system
cd /home/chip

###################################
# WiRoc-Python-2
###################################
log "Installing WiRoc-Python-2 ${WiRocPythonVersion}"
wget -q -O installWiRocPython.py https://raw.githubusercontent.com/henla464/WiRoc-Python-2/master/installWiRocPython.py
chmod ugo+x installWiRocPython.py
./installWiRocPython.py "$WiRocPythonVersion" NEW

cd WiRoc-Python-2
python3 -m venv env
env/bin/pip install -r requirements.txt
# wheel filename varies with the python version (cp313 on trixie); use a glob
env/bin/pip install ../reedsolomon/dist/reedsolo-*.whl
cd /home/chip

wget -q -O /etc/systemd/system/WiRocPython.service https://raw.githubusercontent.com/henla464/WiRoc-StartupScripts/master/WiRocPython.service
wget -q -O /etc/systemd/system/WiRocPythonWS.service https://raw.githubusercontent.com/henla464/WiRoc-StartupScripts/master/WiRocPythonWS.service
systemctl --no-reload enable WiRocPython.service
systemctl --no-reload enable WiRocPythonWS.service

###################################
# WiRoc-StartupScripts
###################################
log "Installing WiRoc-StartupScripts"
mkdir -p WiRoc-StartupScripts
wget -q -O /home/chip/WiRoc-StartupScripts/Startup.py https://raw.githubusercontent.com/henla464/WiRoc-StartupScripts/master/Startup.py
wget -q -O /home/chip/WiRoc-StartupScripts/requirements.txt https://raw.githubusercontent.com/henla464/WiRoc-StartupScripts/master/requirements.txt
chmod +x /home/chip/WiRoc-StartupScripts/Startup.py

cd WiRoc-StartupScripts
python3 -m venv env
env/bin/pip install -r requirements.txt
cd /home/chip

wget -q -O /etc/systemd/system/WiRocStartup.service https://raw.githubusercontent.com/henla464/WiRoc-StartupScripts/master/WiRocStartup.service
systemctl --no-reload enable WiRocStartup.service

###################################
# WiRoc-WatchDog
###################################
log "Installing WiRoc-WatchDog"
mkdir -p WiRoc-WatchDog
wget -q -O /home/chip/WiRoc-WatchDog/WiRoc-WatchDog.py https://raw.githubusercontent.com/henla464/WiRoc-WatchDog/master/WiRoc-WatchDog.py
wget -q -O /home/chip/WiRoc-WatchDog/requirements.txt https://raw.githubusercontent.com/henla464/WiRoc-WatchDog/master/requirements.txt
chmod +x /home/chip/WiRoc-WatchDog/WiRoc-WatchDog.py

cd WiRoc-WatchDog
python3 -m venv env
env/bin/pip install -r requirements.txt
cd /home/chip

wget -q -O /etc/systemd/system/WiRocWatchDog.service https://raw.githubusercontent.com/henla464/WiRoc-WatchDog/master/WiRocWatchDog.service
systemctl --no-reload enable WiRocWatchDog.service

###################################
# RTC (pcf8563) — not used on v3Rev2/v4Rev1/v6Rev1
###################################
if [[ "$WiRocHWVersion" == "v3Rev2" || "$WiRocHWVersion" == "v4Rev1" || "$WiRocHWVersion" == "v6Rev1" ]]; then
    log "Skipping RTC (not used on $WiRocHWVersion)"
else
    log "Installing RTC (pcf8563)"
    apt-get install -y util-linux-extra
    if ! grep -Fxq "rtc_pcf8563" /etc/modules; then
        echo "rtc_pcf8563" >> /etc/modules
    fi
    # NOTE: at build time /sys/class/rtc reflects the build host, not the target,
    # so (unlike install.sh) we can't probe for the pcf8563's rtc number. Match the
    # parent i2c client's driver instead: the rtc device's 'name' attribute is
    # "rtc-pcf8563 <parent-dev>" (e.g. "rtc-pcf8563 0-0051"), so
    # ATTR{name}=="rtc-pcf8563" would never match. DRIVERS walks the parent chain,
    # so this fires on the correct rtcN regardless of enumeration order.
    # link_priority=100 (higher wins, default 0) overrides the stock
    # 50-udev-default.rules rule that links rtc0 (hctosys==1) as /dev/rtc.
    if [[ ! -f /usr/lib/udev/rules.d/51-udev-rtc.rules ]]; then
        echo 'SUBSYSTEM=="rtc", DRIVERS=="rtc-pcf8563", SYMLINK+="rtc", OPTIONS+="link_priority=100"' > /usr/lib/udev/rules.d/51-udev-rtc.rules
    fi
fi

###################################
# Bluetooth: compat mode (+ SP profile on older HW)
###################################
log "Configuring bluetooth service"
if ! grep -Fq 'compat' /lib/systemd/system/bluetooth.service; then
    sed -i -E "s@(ExecStart=).*@ExecStart=/usr/libexec/bluetooth/bluetoothd --compat --noplugin=sap@" /lib/systemd/system/bluetooth.service
fi

if [[ "$WiRocHWVersion" == "v3Rev2" || "$WiRocHWVersion" == "v4Rev1" || "$WiRocHWVersion" == "v6Rev1" ]]; then
    if ! grep -Fxq 'ExecStartPost=/usr/bin/sdptool add SP' /lib/systemd/system/bluetooth.service; then
        sed -i '/ExecStart=.*/a ExecStartPost=/usr/bin/sdptool add SP' /lib/systemd/system/bluetooth.service
    fi
fi

###################################
# Tailscale
###################################
log "Installing tailscale"
mkdir -p --mode=0755 /usr/share/keyrings
curl -fsSL https://pkgs.tailscale.com/stable/debian/trixie.noarmor.gpg | tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
curl -fsSL https://pkgs.tailscale.com/stable/debian/trixie.tailscale-keyring.list | tee /etc/apt/sources.list.d/tailscale.list

apt-get update
apt-get install -y tailscale
# Make sure tailscaled is enabled even if the package postinst skipped it in chroot
systemctl --no-reload enable tailscaled.service >/dev/null 2>&1 || true

wget -q -O /usr/local/sbin/tailscale-auto-route.sh https://raw.githubusercontent.com/henla464/WiRoc-StartupScripts/master/tailscale-auto-route.sh
chmod +x /usr/local/sbin/tailscale-auto-route.sh
wget -q -O /etc/systemd/system/tailscale-auto-route.service https://raw.githubusercontent.com/henla464/WiRoc-StartupScripts/master/tailscale-auto-route.service

mkdir -p /etc/NetworkManager/dispatcher.d
wget -q -O /etc/NetworkManager/dispatcher.d/90-tailscale-auto-route https://raw.githubusercontent.com/henla464/WiRoc-StartupScripts/master/90-tailscale-auto-route
chmod +x /etc/NetworkManager/dispatcher.d/90-tailscale-auto-route

###################################
# boot.cmd: force a sane video-mode (headless HDMI)
###################################
log "Updating boot.cmd (video-mode)"
if ! grep -Fxq "setenv video-mode sunxi:1920x1080,monitor=none,hpd=0,edid=1" /boot/boot.cmd; then
    sed -i '$a setenv video-mode sunxi:1920x1080,monitor=none,hpd=0,edid=1' /boot/boot.cmd
    sed -i '$a saveenv' /boot/boot.cmd
    mkimage -C none -A arm -T script -d /boot/boot.cmd /boot/boot.scr
fi

###################################
# armbian-config --cmd SY203 equivalent: freeze kernel + board support packages
###################################
log "Freezing kernel + board support packages (SY203)"
PACKAGES_TO_HOLD="$(dpkg-query -W -f='${Package}\n' 2>/dev/null | grep -E '^(linux-image-|linux-dtb-|linux-headers-|linux-u-boot-|armbian-)' || true)"
if [[ -n "$PACKAGES_TO_HOLD" ]]; then
    # shellcheck disable=SC2086
    apt-mark hold $PACKAGES_TO_HOLD >/dev/null 2>&1 || true
fi
echo "Held packages:"; apt-mark showhold || true

###################################
# armbian-config --cmd UNAT03 equivalent: disable unattended upgrades
###################################
log "Disabling unattended upgrades (UNAT03)"
systemctl --no-reload disable unattended-upgrades.service unattended-upgrades.timer \
    apt-daily.service apt-daily.timer apt-daily-upgrade.service apt-daily-upgrade.timer >/dev/null 2>&1 || true
cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Enable "0";
APT::Periodic::Update-Package-Lists "0";
APT::Periodic::Download-Upgradeable-Packages "0";
APT::Periodic::Unattended-Upgrade "0";
APT::Periodic::AutocleanInterval "0";
EOF

###################################
# armbian-config --cmd SY207 equivalent: ensure stable Armbian repo
###################################
log "Ensuring stable Armbian repo (SY207)"
if [[ -f /etc/apt/sources.list.d/armbian.sources ]]; then
    sed -i -E 's#(^URIs: ).*beta\.armbian\.com.*#\1http://apt.armbian.com#' /etc/apt/sources.list.d/armbian.sources
    grep -q "apt.armbian.com" /etc/apt/sources.list.d/armbian.sources || echo "WARN: armbian.sources does not point at apt.armbian.com"
fi

###################################
# Fix ownership: everything under /home/chip belongs to chip
###################################
log "Fixing ownership of /home/chip"
chown -R chip:chip /home/chip

###################################
# Sanity checks: the release installers exit 0 even when they can't find the
# requested version, so verify the expected results are actually present.
###################################
log "Verifying installation"
[[ -d /home/chip/WiRoc-BLE-API/env ]]   || { echo "FATAL: /home/chip/WiRoc-BLE-API/env missing" >&2; exit 1; }
[[ -d /home/chip/WiRoc-Python-2/env ]]  || { echo "FATAL: /home/chip/WiRoc-Python-2/env missing" >&2; exit 1; }
for svc in WiRocBLEAPI WiRocPython WiRocPythonWS WiRocStartup WiRocWatchDog; do
    [[ -f /etc/systemd/system/${svc}.service ]] || { echo "FATAL: missing ${svc}.service" >&2; exit 1; }
done

log "install-wiroc.sh complete"
