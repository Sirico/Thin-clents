#!/bin/bash

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run as root: sudo $0"
    exit 1
fi

# Function to exit script on error
function exit_on_error {
    echo "Error encountered. Exiting."
    exit 1
}

# 1. Set the hostname to Dispatch-station
echo "Setting hostname to Dispatch-station..."
hostnamectl set-hostname Dispatch-station || exit_on_error

# Update /etc/hosts to reflect the new hostname
sed -i 's/127\.0\.1\.1.*/127.0.1.1\tDispatch-station/' /etc/hosts || exit_on_error

# 2. Enable auto-login for the primary user
echo "Configuring auto-login..."

# Attempt to use the user who invoked sudo
USERNAME="${SUDO_USER}"

# If SUDO_USER is not set, prompt for username
if [ -z "$USERNAME" ]; then
    read -p "Enter the username for auto-login: " USERNAME
fi

# Verify that the user exists
if ! id "$USERNAME" >/dev/null 2>&1; then
    echo "User '$USERNAME' does not exist. Please create the user before running this script."
    exit 1
fi

# Create LightDM configuration directory if it doesn't exist
LIGHTDM_CONF_DIR="/etc/lightdm/lightdm.conf.d"
mkdir -p "$LIGHTDM_CONF_DIR" || exit_on_error

# Create the autologin configuration file
AUTLOGIN_CONF="$LIGHTDM_CONF_DIR/50-autologin.conf"

cat > "$AUTLOGIN_CONF" <<EOF
[Seat:*]
autologin-user=$USERNAME
autologin-user-timeout=0
EOF

echo "Auto-login configured for user '$USERNAME'."

# 3. Install Remmina and Firefox as snaps
echo "Installing Remmina and Firefox..."
/usr/bin/snap install remmina || exit_on_error
/usr/bin/snap install firefox || exit_on_error

# 4. Install and enable Cockpit
echo "Installing and enabling Cockpit..."
/usr/bin/apt update -y || exit_on_error
/usr/bin/apt install -y cockpit || exit_on_error
/usr/bin/systemctl enable --now cockpit.socket || exit_on_error

# 5. Enable unattended upgrades
echo "Enabling unattended upgrades..."
/usr/bin/apt install -y unattended-upgrades || exit_on_error

# Configure unattended-upgrades without overwriting existing settings
AUTO_UPGRADES_CONF="/etc/apt/apt.conf.d/20auto-upgrades"

# Check if the file exists and modify accordingly
if [ -f "$AUTO_UPGRADES_CONF" ]; then
    echo "Updating existing unattended-upgrades configuration..."
    sed -i 's/^APT::Periodic::Update-Package-Lists.*/APT::Periodic::Update-Package-Lists "1";/' "$AUTO_UPGRADES_CONF"
    sed -i 's/^APT::Periodic::Unattended-Upgrade.*/APT::Periodic::Unattended-Upgrade "1";/' "$AUTO_UPGRADES_CONF"
else
    echo "Creating unattended-upgrades configuration..."
    cat > "$AUTO_UPGRADES_CONF" <<EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
fi

# Start unattended-upgrades service
/usr/bin/systemctl enable --now unattended-upgrades || exit_on_error

# 6. Configure Remmina to start on login
echo "Configuring Remmina to start on login..."

# Create autostart directory if it doesn't exist
AUTOSTART_DIR="/home/$USERNAME/.config/autostart"
mkdir -p "$AUTOSTART_DIR" || exit_on_error

# Create the desktop entry for Remmina
REM_DESKTOP_FILE="$AUTOSTART_DIR/remmina.desktop"
cat > "$REM_DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Exec=remmina
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Remmina
Comment=Start Remmina on login
EOF

# Set ownership of the desktop entry file
chown "$USERNAME:$USERNAME" "$REM_DESKTOP_FILE" || exit_on_error

echo "Remmina configured to start on login for user '$USERNAME'."

echo "All tasks completed successfully!"
echo "A reboot is required for all changes to take effect."
