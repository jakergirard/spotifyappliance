import psutil
import time
import threading
import logging
from typing import Dict, List

class HealthMonitor:
    def __init__(self):
        self.logger = logging.getLogger('health_monitor')
        self.checks: Dict[str, bool] = {
            'audio': False,
            'network': False,
            'spotify': False
        }
        self.recovery_attempts: Dict[str, int] = {}
        
    def start(self):
        threading.Thread(target=self._monitor_loop, daemon=True).start()
    
    def _monitor_loop(self):
        while True:
            try:
                self._check_system_health()
                time.sleep(60)  # Check every minute
            except Exception as e:
                self.logger.error(f"Health check error: {e}")
                time.sleep(10)
    
    def _check_system_health(self):
        # Check CPU usage
        cpu_percent = psutil.cpu_percent(interval=1)
        if cpu_percent > 80:
            self.logger.warning(f"High CPU usage: {cpu_percent}%")
        
        # Check memory usage
        memory = psutil.virtual_memory()
        if memory.percent > 80:
            self.logger.warning(f"High memory usage: {memory.percent}%")
        
        # Check disk space
        disk = psutil.disk_usage('/')
        if disk.percent > 80:
            self.logger.warning(f"Low disk space: {disk.percent}%")
        
        # Check network connectivity
        self._check_network()
        
        # Log health status
        self.logger.info(f"Health status: {self.checks}")
    
    def _check_network(self):
        import socket
        try:
            socket.create_connection(("8.8.8.8", 53), timeout=3)
            self.checks['network'] = True
        except OSError:
            self.checks['network'] = False
            self._attempt_recovery('network')
    
    def _attempt_recovery(self, service: str):
        attempts = self.recovery_attempts.get(service, 0) + 1
        self.recovery_attempts[service] = attempts
        
        if attempts > 3:
            self.logger.error(f"Multiple recovery attempts failed for {service}")
            # Reset counter after waiting period
            if attempts > 10:
                self.recovery_attempts[service] = 0
            return
        
        self.logger.info(f"Attempting recovery for {service}")
        
        if service == 'network':
            self._recover_network()
        elif service == 'audio':
            self._recover_audio()
        elif service == 'spotify':
            self._recover_spotify()
    
    def _recover_network(self):
        import subprocess
        try:
            # Try to restart networking
            subprocess.run(['systemctl', 'restart', 'systemd-networkd'], check=True)
            time.sleep(5)
            # If still failed, try to restart the interface
            if not self.checks['network']:
                subprocess.run(['ip', 'link', 'set', 'wlan0', 'down'], check=True)
                time.sleep(2)
                subprocess.run(['ip', 'link', 'set', 'wlan0', 'up'], check=True)
        except Exception as e:
            self.logger.error(f"Network recovery failed: {e}")
    
    def _recover_audio(self):
        import subprocess
        try:
            # Restart ALSA
            subprocess.run(['alsactl', 'restore'], check=True)
            # If still failed, try to reload the sound module
            if not self.checks['audio']:
                subprocess.run(['modprobe', '-r', 'snd_bcm2835'], check=True)
                time.sleep(2)
                subprocess.run(['modprobe', 'snd_bcm2835'], check=True)
        except Exception as e:
            self.logger.error(f"Audio recovery failed: {e}")
    
    def _recover_spotify(self):
        # Signal the PlaybackService to reinitialize
        if hasattr(self, 'playback_service'):
            self.playback_service.initialize_spotify()
    
    def _cleanup_disk(self):
        """Perform disk cleanup when space is low"""
        import subprocess
        import os
        
        # Clean old logs
        subprocess.run(['journalctl', '--vacuum-time=7d'], check=True)
        
        # Clean package cache
        subprocess.run(['apt-get', 'clean'], check=True)
        
        # Remove old cache files
        cache_dir = '/opt/spotify-appliance/instance/cache'
        if os.path.exists(cache_dir):
            for file in os.listdir(cache_dir):
                if os.path.getmtime(os.path.join(cache_dir, file)) < time.time() - 7*86400:
                    os.remove(os.path.join(cache_dir, file))
    
    def _check_updates(self):
        """Check and apply security updates"""
        import subprocess
        try:
            # Only run once per day
            if time.time() - self.last_update_check < 86400:
                return
            
            self.last_update_check = time.time()
            subprocess.run(['unattended-upgrade', '-d'], check=True)
        except Exception as e:
            self.logger.error(f"Update check failed: {e}")