import time
import logging
from spotipy import Spotify
from spotipy.oauth2 import SpotifyOAuth

logger = logging.getLogger(__name__)

class PlaybackService:
    def __init__(self):
        self.spotify = None
        self.device_id = None
        self.is_playing = False
        self.current_track = None
        
    def initialize_spotify(self):
        """Initialize Spotify client and get device ID"""
        try:
            self.spotify = Spotify(auth_manager=SpotifyOAuth(
                client_id="YOUR_CLIENT_ID",
                client_secret="YOUR_CLIENT_SECRET",
                redirect_uri="http://localhost:5000/callback",
                scope="user-modify-playback-state user-read-playback-state streaming",
                open_browser=False,
                cache_path="/opt/spotify-appliance/instance/.spotify_cache"
            ))
            
            # Get available devices and set our device ID
            devices = self.spotify.devices()
            for device in devices['devices']:
                if device['name'] == "Spotify Appliance":
                    self.device_id = device['id']
                    logger.info(f"Found Spotify device: {self.device_id}")
                    break
            
            if not self.device_id:
                logger.warning("Spotify device not found")
                
            return True
        except Exception as e:
            logger.error(f"Failed to initialize Spotify: {e}")
            return False
        
    def start(self):
        """Start playback service"""
        while True:
            try:
                if not self.spotify:
                    if not self.initialize_spotify():
                        time.sleep(5)
                        continue

                if not self.is_playing:
                    self.ensure_playback()
                time.sleep(1)
            except Exception as e:
                logger.error(f"Playback error: {e}")
                time.sleep(5)
    
    def ensure_playback(self):
        """Ensure music is playing"""
        try:
            if not self.current_track and self.device_id:
                self.spotify.start_playback(device_id=self.device_id)
                self.is_playing = True
                logger.info("Started playback")
        except Exception as e:
            logger.error(f"Failed to ensure playback: {e}")
    
    def reclaim_playback(self):
        """Force playback to this device"""
        try:
            if self.device_id:
                self.spotify.transfer_playback(device_id=self.device_id, force_play=True)
                logger.info("Reclaimed playback")
        except Exception as e:
            logger.error(f"Failed to reclaim playback: {e}") 