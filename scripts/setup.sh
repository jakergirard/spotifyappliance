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
    # Create service user
    useradd -r -s /bin/false spotify-appliance

    # Create application directory
    mkdir -p /opt/spotify-appliance
    chown spotify-appliance:spotify-appliance /opt/spotify-appliance

    # Set up Python virtual environment
    python3 -m venv /opt/spotify-appliance/venv
    source /opt/spotify-appliance/venv/bin/activate
    pip install -r requirements.txt

    # Install systemd service
    cp spotify-appliance.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl enable spotify-appliance
}

# Audio configuration
configure_audio() {
    # Set up ALSA with fallback configuration
    cat > /etc/asound.conf << EOF
pcm.!default {
    type plug
    slave.pcm "fallback"
}

pcm.fallback {
    type hw
    card 0
    device 0
}

# Mono output configuration
pcm.mono {
    type route
    slave.pcm "fallback"
    ttable.0.0 0.5
    ttable.1.0 0.5
}
EOF
}

# Main installation process
echo "Starting Spotify Appliance installation..."

configure_base_system
harden_system
setup_application
configure_audio

echo "Installation complete. Please configure Spotify credentials via web interface." 