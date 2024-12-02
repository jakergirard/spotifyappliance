import time
import logging

logger = logging.getLogger(__name__)

class DeviceMonitor:
    def __init__(self, playback_service):
        self.playback_service = playback_service
        self.should_monitor = True
        
    def start(self):
        """Start device monitoring"""
        logger.info("Starting device monitor")
        while self.should_monitor:
            try:
                self.check_playback_device()
                time.sleep(5)
            except Exception as e:
                logger.error(f"Device monitor error: {e}")
                time.sleep(5)
    
    def check_playback_device(self):
        """Check if playback is on our device, reclaim if necessary"""
        try:
            current_playback = self.playback_service.spotify.current_playback()
            if current_playback and current_playback['device']['id'] != self.playback_service.device_id:
                logger.info("Playback detected on different device, reclaiming...")
                self.playback_service.reclaim_playback()
        except Exception as e:
            logger.error(f"Failed to check playback device: {e}")
    