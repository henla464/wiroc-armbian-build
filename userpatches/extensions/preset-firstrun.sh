function post_family_tweaks__preset_configs() {
	display_alert "$BOARD" "preset configs for rootfs" "info"
	# Set PRESET_NET_CHANGE_DEFAULTS to 1 to apply any network related settings below
	echo "PRESET_NET_CHANGE_DEFAULTS=1" > "${SDCARD}"/root/.not_logged_in_yet

	# Enable WiFi or Ethernet.
	#      NB: If both are enabled, WiFi will take priority and Ethernet will be disabled.
	echo "PRESET_NET_ETHERNET_ENABLED=1" >> "${SDCARD}"/root/.not_logged_in_yet
	echo "PRESET_NET_WIFI_ENABLED=1" >> "${SDCARD}"/root/.not_logged_in_yet

	#Enter your WiFi creds
	#      SECURITY WARN: Your wifi keys will be stored in plaintext, no encryption.
	echo "PRESET_NET_WIFI_SSID='WiRoc'" >> "${SDCARD}"/root/.not_logged_in_yet
	echo "PRESET_NET_WIFI_KEY='WiRocWiRoc'" >> "${SDCARD}"/root/.not_logged_in_yet

	#      Country code to enable power ratings and channels for your country. eg: GB US DE | https://en.wikipedia.org/wiki/ISO_3166-1_alpha-2
	echo "PRESET_NET_WIFI_COUNTRYCODE='SE'" >> "${SDCARD}"/root/.not_logged_in_yet

	#If you want to use a static ip, set it here
	#echo "PRESET_NET_USE_STATIC=1" >> "${SDCARD}"/root/.not_logged_in_yet
	#echo "PRESET_NET_STATIC_IP='192.168.0.100'" >> "${SDCARD}"/root/.not_logged_in_yet
	#echo "PRESET_NET_STATIC_MASK='255.255.255.0'" >> "${SDCARD}"/root/.not_logged_in_yet
	#echo "PRESET_NET_STATIC_GATEWAY='192.168.0.1'" >> "${SDCARD}"/root/.not_logged_in_yet
	#echo "PRESET_NET_STATIC_DNS='8.8.8.8 8.8.4.4'" >> "${SDCARD}"/root/.not_logged_in_yet

	# Preset user default shell, you can choose bash or  zsh
	echo "PRESET_USER_SHELL=bash" >> "${SDCARD}"/root/.not_logged_in_yet

	# Set PRESET_CONNECT_WIRELESS=y if you want to connect wifi manually at first login, n uses values from .not_logged_in_yet
	echo "PRESET_CONNECT_WIRELESS=n" >> "${SDCARD}"/root/.not_logged_in_yet

	# Set SET_LANG_BASED_ON_LOCATION=n if you want to choose "Set user language based on your location?" with "n" at first login
	echo "SET_LANG_BASED_ON_LOCATION=y" >> "${SDCARD}"/root/.not_logged_in_yet

	# Preset default locale
	echo "PRESET_LOCALE=en_GB.UTF-8" >> "${SDCARD}"/root/.not_logged_in_yet

	# Preset timezone
	echo "PRESET_TIMEZONE=Europe/Stockholm" >> "${SDCARD}"/root/.not_logged_in_yet

	# NOTE: no default root/user password is baked (EU Radio Equipment Directive
	# 2022/30). At first login armbian-firstlogin prompts the user to set their own
	# root + chip passwords. To pre-set them (non-interactive/provisioned), add the
	# lines below to /root/.not_logged_in_yet before first boot:
	#   PRESET_ROOT_PASSWORD=...
	#   PRESET_USER_PASSWORD=...

	# Preset username
	echo "PRESET_USER_NAME=chip" >> "${SDCARD}"/root/.not_logged_in_yet

	# Preset user default realname
	echo "PRESET_DEFAULT_REALNAME=Chip" >> "${SDCARD}"/root/.not_logged_in_yet
}
