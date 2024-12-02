import time

class DeviceMonitor:
    def __init__(self, playback_service):
        self.playback_service = playback_service
        self.should_monitor = True
        
    def start(self):
        while self.should_monitor:
            try:
                self.check_playback_device()
                time.sleep(5)
            except Exception as e:
                print(f"Device monitor error: {e}")
                time.sleep(5)
    
    def check_playback_device(self):
        """Check if playback is on our device, reclaim if necessary"""
        current_playback = self.playback_service.spotify.current_playback()
        if current_playback and current_playback['device']['id'] != self.playback_service.device_id:
            self.playback_service.reclaim_playback() 