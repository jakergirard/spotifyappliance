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
PermitRootLogin no
PasswordAuthentication no
X11Forwarding no
EOF

    systemctl restart ssh
    systemctl restart fail2ban
}

# Application setup
setup_application() {
    # Create application directory structure
    APP_DIR=/opt/spotify-appliance
    echo "Creating application directories..."
    mkdir -p ${APP_DIR}/{instance,logs}

    # Create requirements.txt if it doesn't exist
    if [ ! -f "requirements.txt" ]; then
        echo "Creating requirements.txt..."
        cat > requirements.txt << 'EOF'
flask==3.0.0
spotipy==2.23.0
python-alsaaudio==0.10.0
psutil==5.9.6
requests==2.31.0
EOF
    fi

    # Create service file if it doesn't exist
    if [ ! -f "spotify-appliance.service" ]; then
        echo "Creating service file..."
        cat > spotify-appliance.service << 'EOF'
[Unit]
Description=Spotify Appliance Service
After=network-online.target sound.target
Wants=network-online.target
StartLimitIntervalSec=300
StartLimitBurst=5

[Service]
Type=simple
User=spotify-appliance
Group=audio
WorkingDirectory=/opt/spotify-appliance
Environment=DISPLAY=:0
ExecStart=/opt/spotify-appliance/venv/bin/python3 main.py

# Watchdog configuration
WatchdogSec=30
Restart=always
RestartSec=10
TimeoutStartSec=60
TimeoutStopSec=30

# Security hardening
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=/opt/spotify-appliance/instance
PrivateTmp=yes
CapabilityBoundingSet=
AmbientCapabilities=

[Install]
WantedBy=multi-user.target
EOF
    fi

    # Create basic app structure if it doesn't exist
    if [ ! -d "app" ]; then
        echo "Creating application structure..."
        mkdir -p app/services
        touch app/__init__.py
        # Add your service files here
    fi

    # Create service user
    echo "Configuring service user..."
    useradd -r -s /bin/false spotify-appliance || true  # Don't fail if user exists
    usermod -aG audio spotify-appliance  # Ensure user has audio permissions
    chown -R spotify-appliance:spotify-appliance ${APP_DIR}

    # Copy application files
    echo "Installing application files..."
    if [ -d "app" ]; then
        cp -r app ${APP_DIR}/
        cp main.py ${APP_DIR}/
    else
        echo "ERROR: Application files not found in current directory"
        echo "Please ensure you're running this script from the project root directory"
        echo "Current directory contains: $(ls)"
        exit 1
    fi

    # Set up Python virtual environment
    echo "Setting up Python environment..."
    python3 -m venv ${APP_DIR}/venv
    source ${APP_DIR}/venv/bin/activate
    
    # Install Python dependencies
    echo "Installing Python dependencies..."
    if [ -f "requirements.txt" ]; then
        pip install --upgrade pip
        pip install -r requirements.txt
    else
        echo "ERROR: requirements.txt not found"
        echo "Current directory contains: $(ls)"
        exit 1
    fi

    # Install systemd service
    echo "Installing systemd service..."
    if [ -f "spotify-appliance.service" ]; then
        cp spotify-appliance.service /etc/systemd/system/
    else
        echo "ERROR: spotify-appliance.service not found"
        echo "Current directory contains: $(ls)"
        exit 1
    fi

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