#!/bin/bash

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
   echo "This script must be run as root. Use sudo ./post-install.sh" 
   exit 1
fi

# Set hostname
echo "Dispatch-station" > /etc/hostname
hostnamectl set-hostname Dispatch-station
echo "127.0.1.1 Dispatch-station" >> /etc/hosts
echo "Hostname set to Dispatch-station."

# Create user 'user' with password 'password' (replace with a secure password)
PASSWORD_HASH=$(openssl passwd -6 'password')
useradd -m -s /bin/bash -p "$PASSWORD_HASH" user
usermod -aG sudo user
echo "User 'user' created and added to sudo group."

# Enable automatic login for the user
GDM_CONF="/etc/gdm3/custom.conf"
if grep -q "AutomaticLoginEnable" "$GDM_CONF"; then
    sed -i "s/^.*AutomaticLoginEnable.*$/AutomaticLoginEnable=true/" "$GDM_CONF"
else
    echo "AutomaticLoginEnable=true" >> "$GDM_CONF"
fi

if grep -q "AutomaticLogin" "$GDM_CONF"; then
    sed -i "s/^.*AutomaticLogin=.*$/AutomaticLogin=user/" "$GDM_CONF"
else
    echo "AutomaticLogin=user" >> "$GDM_CONF"
fi
echo "Automatic login enabled for user 'user'."

# Update package lists
apt update

# Install Remmina via Snap
snap install remmina
echo "Remmina installed via Snap."

# Install Cockpit and unattended-upgrades
apt install -y cockpit unattended-upgrades
echo "Cockpit and unattended-upgrades installed."

# Enable Cockpit service
systemctl enable --now cockpit.socket
echo "Cockpit service enabled and started."

# Configure unattended upgrades
dpkg-reconfigure --priority=low unattended-upgrades
echo "Unattended upgrades configured."

# Clean up and reboot (optional)
echo "Post-installation tasks completed."
# reboot
