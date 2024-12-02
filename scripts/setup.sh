#!/bin/bash

# System Configuration and Hardening Script for Spotify Appliance

set -e  # Exit on any error

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

# Base system configuration
configure_base_system() {
    # Update package lists
    apt-get update

    # Install only essential packages
    apt-get install -y \
        python3-pip \
        python3-venv \
        git \
        libasound2-dev \
        ufw \
        fail2ban \
        alsa-utils \
        i2c-tools \
        python3-alsaaudio \
        unattended-upgrades

    # Configure automatic security updates
    cat > /etc/apt/apt.conf.d/20auto-upgrades << EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF

    # Configure unattended-upgrades for security only
    cat > /etc/apt/apt.conf.d/50unattended-upgrades << EOF
Unattended-Upgrade::Allowed-Origins {
    "\${distro_id}:\${distro_codename}-security";
};
Unattended-Upgrade::Package-Blacklist {
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
EOF

    # Enable hardware watchdog
    if grep -q "bcm2835_wdt" /proc/modules || modprobe bcm2835_wdt; then
        echo "bcm2835_wdt" >> /etc/modules
        
        # Configure systemd watchdog
        mkdir -p /etc/systemd/system.conf.d/
        cat > /etc/systemd/system.conf.d/watchdog.conf << EOF
[Manager]
RuntimeWatchdogSec=60
ShutdownWatchdogSec=10min
EOF
    else
        echo "Hardware watchdog not available, skipping watchdog configuration"
    fi

    # Configure log rotation
    cat > /etc/logrotate.d/spotify-appliance << EOF
/var/log/spotify-appliance.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 640 spotify-appliance spotify-appliance
}
EOF
}

# Security hardening
harden_system() {
    # Configure firewall
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow 5000/tcp  # Web interface
    ufw allow ssh
    ufw --force enable

    # Configure fail2ban
    cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true
EOF

    # Secure SSH configuration
    cat > /etc/ssh/sshd_config.d/hardening.conf << EOF
PermitRootLogin yes
PasswordAuthentication yes
X11Forwarding no
EOF

    systemctl restart ssh
    systemctl restart fail2ban
}

# Application setup
setup_application() {
    # Create application directory structure
    APP_DIR=/opt/spotify-appliance
    PROJECT_ROOT="$(dirname "$(dirname "$(readlink -f "$0")")")"
    echo "Creating application directories..."
    mkdir -p ${APP_DIR}/{instance,logs}

    # Create default instance config
    echo "Creating default configuration..."
    # Generate a random secret key
    SECRET_KEY=$(python3 -c 'import secrets; print(secrets.token_hex(32))')
    cat > ${APP_DIR}/instance/config.json << EOF
{
    "SECRET_KEY": "${SECRET_KEY}",
    "SPOTIFY_CLIENT_ID": null,
    "SPOTIFY_CLIENT_SECRET": null,
    "SPOTIFY_REDIRECT_URI": "http://localhost:5000/callback",
    "DEFAULT_VOLUME": 70,
    "FORCE_MONO": true
}
EOF
    chown spotify-appliance:spotify-appliance ${APP_DIR}/instance/config.json
    chmod 644 ${APP_DIR}/instance/config.json

    # Create Spotify cache file
    touch ${APP_DIR}/instance/.spotify_cache
    chown spotify-appliance:spotify-appliance ${APP_DIR}/instance/.spotify_cache
    chmod 600 ${APP_DIR}/instance/.spotify_cache

    # Ensure python3-full is installed
    apt-get install -y python3-full

    # Set up Python virtual environment first
    echo "Setting up Python environment..."
    python3 -m venv ${APP_DIR}/venv
    source ${APP_DIR}/venv/bin/activate

    # Copy application files
    echo "Installing application files..."
    if [ -d "${PROJECT_ROOT}/app" ]; then
        cp -r ${PROJECT_ROOT}/app ${APP_DIR}/
        cp ${PROJECT_ROOT}/main.py ${APP_DIR}/
    else
        echo "ERROR: Application files not found"
        echo "Project root (${PROJECT_ROOT}) contains: $(ls "${PROJECT_ROOT}")"
        exit 1
    fi

    # Install Python dependencies
    echo "Installing Python dependencies..."
    # Install build dependencies for alsaaudio
    apt-get install -y python3-dev libasound2-dev pkg-config

    if [ -f "${PROJECT_ROOT}/requirements.txt" ]; then
        ${APP_DIR}/venv/bin/pip install --upgrade pip
        ${APP_DIR}/venv/bin/pip install -r "${PROJECT_ROOT}/requirements.txt"
        # Install alsaaudio in the virtual environment
        ${APP_DIR}/venv/bin/pip install pyalsaaudio
    else
        echo "ERROR: requirements.txt not found"
        echo "Project root (${PROJECT_ROOT}) contains: $(ls "${PROJECT_ROOT}")"
        exit 1
    fi

    # Install systemd service
    echo "Installing systemd service..."
    if [ -f "${PROJECT_ROOT}/spotify-appliance.service" ]; then
        cp "${PROJECT_ROOT}/spotify-appliance.service" /etc/systemd/system/
    else
        echo "ERROR: spotify-appliance.service not found"
        echo "Project root (${PROJECT_ROOT}) contains: $(ls "${PROJECT_ROOT}")"
        exit 1
    fi

    # Create service user and set permissions
    echo "Configuring service user..."
    useradd -r -s /bin/false spotify-appliance || true
    usermod -aG audio spotify-appliance
    chown -R spotify-appliance:spotify-appliance ${APP_DIR}

    # Set up logging
    echo "Setting up logging..."
    touch /var/log/spotify-appliance.log
    chown spotify-appliance:spotify-appliance /var/log/spotify-appliance.log
    chmod 644 /var/log/spotify-appliance.log

    # Enable and start the service
    systemctl daemon-reload
    systemctl enable spotify-appliance
}

# Audio configuration
configure_audio() {
    echo "Configuring audio settings..."
    # Check if I2C is enabled
    if ! grep -q "^dtparam=i2c_arm=on" /boot/config.txt; then
        echo "Enabling I2C..."
        echo "dtparam=i2c_arm=on" >> /boot/config.txt
    fi

    # Enable HiFiBerry DAC+ ADC Pro
    if ! grep -q "^dtoverlay=hifiberry-dacplusadcpro" /boot/config.txt; then
        echo "Configuring HiFiBerry DAC..."
        echo "dtoverlay=hifiberry-dacplusadcpro" >> /boot/config.txt
    fi
    
    # Disable built-in audio
    echo "Disabling built-in audio..."
    sed -i 's/^dtparam=audio=on/#dtparam=audio=on/' /boot/config.txt
    
    # Set up ALSA with fallback configuration
    echo "Configuring ALSA..."
    cat > /etc/asound.conf << EOF
pcm.!default {
    type plug
    slave.pcm "hifiberry"
}

pcm.hifiberry {
    type hw
    card 0
    device 0
}

# Mono output configuration
pcm.mono {
    type route
    slave.pcm "hifiberry"
    ttable.0.0 0.5
    ttable.1.0 0.5
}
EOF

    # Ensure the module is blacklisted
    echo "Blacklisting built-in audio module..."
    echo "blacklist snd_bcm2835" > /etc/modprobe.d/raspi-blacklist.conf
    
    # Update ALSA module loading order
    echo "Setting up HiFiBerry module..."
    cat > /etc/modprobe.d/hifiberry.conf << EOF
options snd_soc_pcm512x index=0
EOF
}

# Main installation process
echo "Starting Spotify Appliance installation..."
echo "Current directory: $(pwd)"
echo "Directory contents: $(ls)"

echo "Step 1: Configuring base system..."
configure_base_system

echo "Step 2: Hardening system..."
harden_system

echo "Step 3: Setting up application..."
setup_application

echo "Step 4: Configuring audio..."
configure_audio

echo "Installation complete. Please configure Spotify credentials via web interface."
echo "NOTE: A reboot is required for the HiFiBerry DAC to be properly initialized."
echo "Please run 'sudo reboot' after reviewing the configuration." 