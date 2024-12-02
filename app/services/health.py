import psutil
import time
import threading
import logging

logger = logging.getLogger(__name__)

class HealthMonitor:
    def __init__(self):
        self.checks = {
            'audio': False,
            'network': False,
            'spotify': False,
            'disk': True,
            'memory': True
        }
        self.recovery_attempts = {}
        self.last_update_check = 0
        
    def start(self):
        """Start health monitoring"""
        logger.info("Starting health monitor")
        threading.Thread(target=self._monitor_loop, daemon=True).start()
    
    def _monitor_loop(self):
        while True:
            try:
                self._check_system_health()
                time.sleep(60)  # Check every minute
            except Exception as e:
                logger.error(f"Health check error: {e}")
                time.sleep(10)
    
    def _check_system_health(self):
        """Run all health checks"""
        # Check CPU usage
        cpu_percent = psutil.cpu_percent(interval=1)
        if cpu_percent > 80:
            logger.warning(f"High CPU usage: {cpu_percent}%")
        
        # Check memory usage
        memory = psutil.virtual_memory()
        if memory.percent > 80:
            logger.warning(f"High memory usage: {memory.percent}%")
            self.checks['memory'] = False
            self._cleanup_memory()
        else:
            self.checks['memory'] = True
        
        # Check disk space
        disk = psutil.disk_usage('/')
        if disk.percent > 80:
            logger.warning(f"Low disk space: {disk.percent}%")
            self.checks['disk'] = False
            self._cleanup_disk()
        else:
            self.checks['disk'] = True
        
        # Check network connectivity
        self._check_network()
        
        # Log overall health status
        logger.info(f"Health status: {self.checks}")
    
    def _check_network(self):
        """Check network connectivity"""
        import socket
        try:
            socket.create_connection(("8.8.8.8", 53), timeout=3)
            self.checks['network'] = True
        except OSError:
            self.checks['network'] = False
            logger.error("Network connectivity check failed")
            self._attempt_recovery('network')
    
    def _cleanup_disk(self):
        """Clean up disk space"""
        try:
            import subprocess
            # Clean old logs
            subprocess.run(['journalctl', '--vacuum-time=7d'], check=True)
            # Clean package cache
            subprocess.run(['apt-get', 'clean'], check=True)
            logger.info("Disk cleanup completed")
        except Exception as e:
            logger.error(f"Disk cleanup failed: {e}")
    
    def _cleanup_memory(self):
        """Attempt to free memory"""
        try:
            import gc
            gc.collect()
            logger.info("Memory cleanup completed")
        except Exception as e:
            logger.error(f"Memory cleanup failed: {e}")
    
    def _attempt_recovery(self, service: str):
        """Attempt to recover a failed service"""
        attempts = self.recovery_attempts.get(service, 0) + 1
        self.recovery_attempts[service] = attempts
        
        if attempts > 3:
            logger.error(f"Multiple recovery attempts failed for {service}")
            if attempts > 10:
                self.recovery_attempts[service] = 0
            return
        
        logger.info(f"Attempting recovery for {service}")
        
        if service == 'network':
            self._recover_network()
    
    def _recover_network(self):
        """Attempt to recover network connectivity"""
        try:
            import subprocess
            subprocess.run(['systemctl', 'restart', 'systemd-networkd'], check=True)
            logger.info("Network service restarted")
        except Exception as e:
            logger.error(f"Network recovery failed: {e}")