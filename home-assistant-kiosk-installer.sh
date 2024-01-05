#!/bin/bash

# Installer script for Home Assistant Kiosk, that use Firefox

CURRENT_PATH="$(pwd)/"
USER_HOME="$(getent passwd $SUDO_USER | cut -d: -f6)" #home dir of the user behind sudo
HA_KIOSK_DIR="${USER_HOME}/home-assistant-kiosk"
HA_KIOSK_REPRO=https://github.com/AnAxNu/home-assistant-kiosk/archive/refs/heads/master.zip
DEBIAN_VERSION="$(lsb_release -rs)"
EXTRA_PACKAGES=""

# need an extra package in Debian 12
if [ $((DEBIAN_VERSION)) -gt 11 ]
then
  EXTRA_PACKAGES="gldriver-test"
fi

echo
echo "This script installs Home Assistant Kiosk, that use Firefox, "
echo "in the following directory:"
echo $HA_KIOSK_DIR
echo
echo "Currently this is only tested, and working, on"
echo "Debian 11 (Bullseye) and Debian 12 (Bookworm)."
echo "You are currently running Debian $DEBIAN_VERSION."
echo 
echo "EXISTING INSTALLATION, IF ANY, WILL BE OVERWRITTEN."
echo

if [[ $EUID -ne 0 ]]; then
    echo "$0 must be run as root. Try using sudo:"
    echo "sudo $0"
    echo
    exit 2
fi

read -p "CONTINUE? [y/n]" REPLY < /dev/tty
if [[ ! "$REPLY" =~ ^(yes|y|Y)$ ]]; then
	echo "Canceled. "
	exit 0
fi

echo "Updating and upgrading system..."
echo "********************************"
apt -y update
apt -y upgrade
echo

echo "Downloading PHP GPG key...."
echo "***************************"
wget -qO /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
echo

echo "Adding PHP to source list..."
echo "****************************"
echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php.list
echo

echo "Update apt..."
echo "*************"
apt -y update
echo

echo "Installing software..."
echo "**********************"
apt -y install xserver-xorg x11-xserver-utils xinit openbox firefox-esr git php8.3-common php8.3-cli php8.3-curl php8.3-zip $EXTRA_PACKAGES
echo

echo "Setting boot behaviour B2 in raspi-config..."
echo "********************************************"
raspi-config nonint do_boot_behaviour B2
echo

echo "Setting display in OpenBox env..."
echo "*********************************"
echo "export DISPLAY=':0.0'" | tee /etc/xdg/openbox/environment
echo

echo "Setting up OpenBox autostart..."
echo "*******************************"
tee -a /etc/xdg/openbox/autostart << END
xset -dpms            # turn off display power management system
xset s noblank        # turn off screen blanking
xset s off            # turn off screen saver

# run Firefox for Home Assistant kiosk
env MOZ_USE_XINPUT2=1 /usr/bin/firefox --marionette --display=\$DISPLAY --kiosk --private-window 'about:home' &

# give Firefox time to start
sleep 20
/usr/bin/php -f ${HA_KIOSK_DIR}/home-assistant-kiosk-start.php
END
echo

echo "Adding startx to .bash_profile ..."
echo "**********************************"
echo "[[ -z \$DISPLAY && \$XDG_VTNR -eq 1 ]] && startx -- -nocursor" | tee -a "${USER_HOME}/.bash_profile"
echo

echo "Git clone Home Assistant Kiosk repro..."
echo "***************************************"
git clone --recurse-submodules https://github.com/AnAxNu/home-assistant-kiosk.git $HA_KIOSK_DIR
echo

echo "Copying example file to start file..."
echo "*************************************"
cp ${HA_KIOSK_DIR}/home-assistant-kiosk-example.php ${HA_KIOSK_DIR}/home-assistant-kiosk-start.php
chown ${SUDO_USER}:${SUDO_USER} ${HA_KIOSK_DIR}/home-assistant-kiosk-start.php
echo

echo
echo "*************************************************************"
echo "Installation of Home Assistant Kiosk is now complete!"
echo
echo "You now need to edit the Home Assistant Kiosk PHP start file:"
echo "${HA_KIOSK_DIR}/home-assistant-kiosk-start.php"
echo
echo "There you need to change the following values:"
echo "  \$username  - The HA username"
echo "  \$password  - The HA user password"
echo "  \$homeAssistantBaseUrl  - The url to your HA installation"
echo
echo "After you have changed the values you only need to reboot:"
echo "sudo reboot"
echo
echo "Good luck!"
echo
echo "*************************************************************"
