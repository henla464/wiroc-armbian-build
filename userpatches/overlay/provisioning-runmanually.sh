apt update
apt install armbian-config
armbian-config --cmd SY203
armbian-config --cmd UNAT03
armbian-config --cmd SY207

cp /root/install.sh /home/chip
cd /home/chip
./install.sh
shutdown -r 0

