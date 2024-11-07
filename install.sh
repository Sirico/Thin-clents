#!/bin/bash

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run as root: sudo $0"
    exit 1
fi

# 1. Set the hostname to Dispatch-station
echo "Setting hostname to Dispatch-station..."
hostnamectl set-hostname Dispatch-station

# Update /etc/hosts to reflect the new hostname
sed -i "s/127\.0\.1\.1\s.*/127.0.1.1\tDispatch-station/" /etc/hosts

# 2. Enable auto-login for the primary user
echo "Configuring auto-login..."
# Find the primary user (assuming UID 1000)
USERNAME=$(id -nu 1000 2>/dev/null)
if [ -z "$USERNAME" ]; then
    echo "Primary user not found. Please replace 'username' with your actual username."
    USERNAME="username"
fi

# Backup the original LightDM config
LIGHTDM_CONF="/etc/lightdm/lightdm.conf"
if [ ! -f "${LIGHTDM_CONF}.bak" ]; then
    cp "$LIGHTDM_CONF" "${LIGHTDM_CONF}.bak"
fi

# Configure LightDM for auto-login
cat >> "$LIGHTDM_CONF" <<EOF

[Seat:*]
autologin-user=$USERNAME
autologin-user-timeout=0
EOF

# 3. Install Remmina and Firefox as snaps
echo "Installing Remmina and Firefox..."
snap install remmina
snap install firefox

# 4. Install and enable Cockpit
echo "Installing and enabling Cockpit..."
apt update
apt install -y cockpit
systemctl enable --now cockpit.socket

# 5. Enable unattended upgrades
echo "Enabling unattended upgrades..."
apt install -y unattended-upgrades

# Configure unattended-upgrades
AUTO_UPGRADES_CONF="/etc/apt/apt.conf.d/20auto-upgrades"
cat > "$AUTO_UPGRADES_CONF" <<EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF

# Start unattended-upgrades service
systemctl enable --now unattended-upgrades

echo "All tasks completed successfully!"
