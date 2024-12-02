# Spotify Appliance Documentation

## Table of Contents
- [Overview](#overview)
- [Initial Setup](#initial-setup)
  - [Hardware Preparation](#hardware-preparation)
  - [Operating System Installation](#operating-system-installation)
  - [Network Configuration](#network-configuration)
  - [Software Installation](#software-installation)
- [Configuration](#configuration)
  - [System Configuration](#system-configuration)
  - [Spotify Setup](#spotify-setup)
  - [Audio Setup](#audio-setup)
- [Operation](#operation)
- [Maintenance](#maintenance)
- [Troubleshooting](#troubleshooting)
- [Technical Reference](#technical-reference)

## Overview

The Spotify Appliance is a headless Raspberry Pi-based system that provides continuous background music playback via Spotify. It's designed to run 24/7 with minimal intervention, featuring automatic recovery from errors, self-maintenance, and security updates.

### Key Features
- Continuous playback with automatic recovery
- Web-based configuration interface
- Mono audio output support
- Volume persistence
- Automatic playback reclaiming
- Queue management
- Self-healing capabilities
- Automatic security updates
- System health monitoring

## Initial Setup

### Hardware Preparation

1. Required Components:
   - Raspberry Pi (3 or newer recommended)
   - SD Card (8GB minimum, 16GB recommended)
   - Power supply (2.5A minimum recommended)
   - Audio output device
   - Ethernet cable (recommended for initial setup)

2. Hardware Assembly:
   - Insert the SD card
   - Connect audio output
   - Connect ethernet (if using)
   - Connect power supply last

### Operating System Installation

1. Download Raspberry Pi Imager:
   - Visit: https://www.raspberrypi.com/software/
   - Download and install for your platform

2. Flash the OS:
   ```bash
   # Using Raspberry Pi Imager:
   1. Choose OS: "Raspberry Pi OS Lite (64-bit)"
   2. Choose Storage: Select your SD card
   3. Click Advanced Options (gear icon):
      - Set hostname: spotify-appliance
      - Enable SSH
      - Set username/password
      - Configure WiFi (if needed)
   4. Click Write
   ```

3. First Boot:
   - Insert SD card into Raspberry Pi
   - Connect to power
   - Wait 1-2 minutes for initial boot

### Network Configuration

1. Find the Pi's IP address:
   ```bash
   # If using ethernet, check your router's DHCP client list
   # Or use:
   ping spotify-appliance.local
   ```

2. Connect via SSH:
   ```bash
   ssh username@spotify-appliance.local
   ```

### Software Installation

1. Clone the repository:
    ```bash
    git clone https://github.com/jakergirard/spotifyappliance.git
    cd spotifyappliance
    ```

2. Run the installation:
    ```bash
    sudo ./setup.sh
    ```

3. Configure Spotify credentials:
   ```bash
   # Edit the configuration file
   sudo nano /opt/spotify-appliance/app/config/settings.py
   
   # Add your Spotify API credentials:
   SPOTIFY_CLIENT_ID = 'your_client_id'
   SPOTIFY_CLIENT_SECRET = 'your_client_secret'
   ```

4. Reboot to apply audio changes:
   ```bash
   sudo reboot
   ```

## Configuration

### System Configuration

The setup script handles most system configuration automatically, including:
- Security hardening
- Automatic updates
- Watchdog configuration
- Audio setup
- Service installation

Verify the installation:
```bash
sudo systemctl status spotify-appliance
```

### Spotify Setup

1. Create Spotify Developer Application:
   - Visit https://developer.spotify.com/dashboard
   - Create New App
   - Note Client ID and Client Secret
   - Add redirect URI: `http://spotify-appliance.local:5000/callback`

2. Configure Credentials:
   - Access web interface: `http://spotify-appliance.local:5000`
   - Enter Spotify credentials when prompted

### Audio Setup

1. Test audio output:
   ```bash
   # Check if HiFiBerry is detected
   aplay -l
   # Should show "card 0: sndrpihifiberry [snd_rpi_hifiberry_dacplusadc]"
   
   # Test with white noise
   speaker-test -D hw:0 -c2 -t wav
   ```

2. Adjust volume:
   - Use web interface
   - Or command line:
   ```bash
   alsamixer -c 0
   ```

3. HiFiBerry-specific checks:
   ```bash
   # Check I2C device detection
   sudo i2cdetect -y 1
   
   # Check ALSA configuration
   cat /proc/asound/cards
   ```

4. Volume Control Notes:
   - The HiFiBerry DAC+ ADC Pro uses hardware volume control
   - Volume range is -103.5dB to 0dB
   - Digital volume control is recommended for best quality

## Operation

### Service Management

Control the appliance:
```bash
# Start service
sudo systemctl start spotify-appliance

# Stop service
sudo systemctl stop spotify-appliance

# View logs
journalctl -u spotify-appliance -f
```

### Web Interface

Access the control panel:
- URL: `http://spotify-appliance.local:5000`
- Features:
  - Volume control
  - Queue management
  - Playback status
  - Device control

### API Endpoints

```http
# Status
GET /api/status

# Volume Control
POST /api/volume
{
    "volume": 70  # 0-100
}

# Queue Management
GET /api/queue
POST /api/queue/add
{
    "uri": "spotify:track:..."
}
```

## Maintenance

The system is designed for autonomous operation with:
- Automatic security updates
- Log rotation
- Disk space management
- Service recovery
- Health monitoring

### Manual Maintenance

If needed:
```bash
# Check system health
journalctl -u spotify-appliance | grep "health status"

# View logs
tail -f /var/log/spotify-appliance.log

# Update software
sudo apt update && sudo apt upgrade
```

## Troubleshooting

### Common Issues

1. No Sound
   ```bash
   # Check audio device
   aplay -l
   
   # Test audio
   speaker-test -c2 -t wav
   
   # Check volume
   alsamixer
   ```

2. Service Issues
   ```bash
   # Check status
   sudo systemctl status spotify-appliance
   
   # View logs
   journalctl -u spotify-appliance -f
   ```

3. Network Problems
   ```bash
   # Test connectivity
   ping 8.8.8.8
   
   # Check WiFi
   iwconfig
   ```

### Recovery Procedures

Complete reset:
```bash
sudo systemctl stop spotify-appliance
rm -rf /opt/spotify-appliance/instance/*
sudo systemctl start spotify-appliance
```

## Technical Reference

### System Architecture

The appliance consists of several key components:
- PlaybackService: Manages Spotify playback
- DeviceMonitor: Ensures playback control
- HealthMonitor: System health and recovery
- AudioService: Audio output management

### File Locations
```
/opt/spotify-appliance/     # Application directory
/etc/systemd/system/       # Service configuration
/var/log/                  # Log files
/etc/asound.conf          # Audio configuration
```

### Security

The system implements several security measures:
- Minimal attack surface
- Automatic security updates
- Firewall configuration
- Service isolation
- Fail2ban protection

### Monitoring

The HealthMonitor checks:
- CPU usage
- Memory usage
- Disk space
- Network connectivity
- Audio system
- Spotify connection

## Support

For issues and support:
1. Check the logs
2. Review system status
3. Verify network connectivity
4. Check Spotify service status

---

For additional support or to report issues, please visit the project repository.