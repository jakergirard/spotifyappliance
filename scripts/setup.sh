#!/bin/bash

# System Configuration and Hardening Script for Spotify Appliance
set -e  # Exit on any error

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

# Installation paths
APP_DIR=/opt/spotify-appliance
PROJECT_ROOT="$(dirname "$(dirname "$(readlink -f "$0")")")"
INSTANCE_DIR="${APP_DIR}/instance"
LOG_FILE="/var/log/spotify-appliance.log"

echo "Starting Spotify Appliance installation..."
echo "Project root: ${PROJECT_ROOT}"
echo "Installation directory: ${APP_DIR}"

# Base system configuration
configure_base_system() {
    echo "Configuring base system..."
    
    # Update and install dependencies
    apt-get update
    apt-get install -y \
        python3-pip \
        python3-venv \
        python3-dev \
        python3-full \
        git \
        libasound2-dev \
        pkg-config \
        ufw \
        fail2ban \
        alsa-utils \
        i2c-tools

    # Configure automatic security updates
    cat > /etc/apt/apt.conf.d/20auto-upgrades << EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF

    # Configure log rotation
    cat > /etc/logrotate.d/spotify-appliance << EOF
${LOG_FILE} {
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
configure_security() {
    echo "Configuring security..."

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

    systemctl restart fail2ban
}

# Configure audio
configure_audio() {
    echo "Configuring audio..."

    # Enable I2C and HiFiBerry
    if ! grep -q "^dtparam=i2c_arm=on" /boot/config.txt; then
        echo "dtparam=i2c_arm=on" >> /boot/config.txt
    fi
    if ! grep -q "^dtoverlay=hifiberry-dacplusadcpro" /boot/config.txt; then
        echo "dtoverlay=hifiberry-dacplusadcpro" >> /boot/config.txt
    fi
    
    # Disable built-in audio
    sed -i 's/^dtparam=audio=on/#dtparam=audio=on/' /boot/config.txt
    
    # Configure ALSA
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

pcm.mono {
    type route
    slave.pcm "hifiberry"
    ttable.0.0 0.5
    ttable.1.0 0.5
}
EOF

    # Blacklist built-in audio module
    echo "blacklist snd_bcm2835" > /etc/modprobe.d/raspi-blacklist.conf
    
    # Configure HiFiBerry module
    cat > /etc/modprobe.d/hifiberry.conf << EOF
options snd_soc_pcm512x index=0
EOF
}

# Install application
install_application() {
    echo "Installing application..."

    # Create service user
    useradd -r -s /bin/false spotify-appliance || true
    usermod -aG audio spotify-appliance

    # Create directory structure
    mkdir -p ${APP_DIR}/{instance,app/{templates,api,services}}
    
    # Generate secret key and create config
    SECRET_KEY=$(python3 -c 'import secrets; print(secrets.token_hex(32))')
    cat > ${INSTANCE_DIR}/config.json << EOF
{
    "SECRET_KEY": "${SECRET_KEY}",
    "SPOTIFY_CLIENT_ID": null,
    "SPOTIFY_CLIENT_SECRET": null,
    "SPOTIFY_REDIRECT_URI": "http://localhost:5000/callback",
    "DEFAULT_VOLUME": 70,
    "FORCE_MONO": true
}
EOF

    # Copy application files
    if [ -d "${PROJECT_ROOT}/app" ]; then
        # Create necessary __init__.py files if they don't exist
        touch ${PROJECT_ROOT}/app/__init__.py
        touch ${PROJECT_ROOT}/app/api/__init__.py
        touch ${PROJECT_ROOT}/app/services/__init__.py
        mkdir -p ${PROJECT_ROOT}/app/config
        touch ${PROJECT_ROOT}/app/config/__init__.py
        
        # Create settings.py if it doesn't exist
        if [ ! -f "${PROJECT_ROOT}/app/config/settings.py" ]; then
            cat > ${PROJECT_ROOT}/app/config/settings.py << 'EOF'
class Config:
    # Flask settings
    SECRET_KEY = 'dev-key-change-in-production'
    
    # Default settings
    SPOTIFY_CLIENT_ID = " "
    SPOTIFY_CLIENT_SECRET = " "
    SPOTIFY_REDIRECT_URI = 'http://localhost:5000/callback'
    DEFAULT_VOLUME = 50
    FORCE_MONO = True
    
    # Playback settings
    DEFAULT_PLAYLIST_URI = 
    AUTO_RECLAIM_PLAYBACK = True
    RECLAIM_DELAY_SECONDS = 1
EOF
        fi

        cp -r ${PROJECT_ROOT}/app/templates ${APP_DIR}/app/
        cp -r ${PROJECT_ROOT}/app/api ${APP_DIR}/app/
        cp -r ${PROJECT_ROOT}/app/services ${APP_DIR}/app/
        cp -r ${PROJECT_ROOT}/app/config ${APP_DIR}/app/
        cp ${PROJECT_ROOT}/app/__init__.py ${APP_DIR}/app/
        cp ${PROJECT_ROOT}/main.py ${APP_DIR}/
        cp ${PROJECT_ROOT}/requirements.txt ${APP_DIR}/
        cp ${PROJECT_ROOT}/spotify-appliance.service /etc/systemd/system/
    else
        echo "ERROR: Application files not found"
        echo "Project root (${PROJECT_ROOT}) contains: $(ls "${PROJECT_ROOT}")"
        exit 1
    fi

    # Create Spotify cache file
    touch ${INSTANCE_DIR}/.spotify_cache
    chmod 600 ${INSTANCE_DIR}/.spotify_cache

    # Set up Python environment
    python3 -m venv ${APP_DIR}/venv
    ${APP_DIR}/venv/bin/pip install --upgrade pip
    ${APP_DIR}/venv/bin/pip install -r ${APP_DIR}/requirements.txt
    ${APP_DIR}/venv/bin/pip install pyalsaaudio

    # Set up logging
    touch ${LOG_FILE}
    
    # Set permissions
    chown -R spotify-appliance:spotify-appliance ${APP_DIR}
    chown spotify-appliance:spotify-appliance ${LOG_FILE}
    chmod -R 755 ${APP_DIR}
    chmod 644 ${LOG_FILE}
    chmod 600 ${INSTANCE_DIR}/config.json
    chmod 600 ${INSTANCE_DIR}/.spotify_cache

    # Enable service
    systemctl daemon-reload
    systemctl enable spotify-appliance
}

# Main installation
echo "Step 1: Base system configuration..."
configure_base_system

echo "Step 2: Security configuration..."
configure_security

echo "Step 3: Audio configuration..."
configure_audio

echo "Step 4: Application installation..."
install_application

echo "Installation complete!"
echo "NOTE: A reboot is required for the HiFiBerry DAC to be properly initialized."
echo "Please configure your Spotify credentials in ${INSTANCE_DIR}/config.json"
echo "Then run: sudo reboot" 