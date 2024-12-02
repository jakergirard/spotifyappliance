import time
import librespot  # We'll use librespot-python for headless Spotify Connect
from spotipy import Spotify
from spotipy.oauth2 import SpotifyOAuth

class PlaybackService:
    def __init__(self):
        self.spotify = None
        self.device_id = None
        self.is_playing = False
        self.current_track = None
        self.spotify_connect = None
        
    def initialize_spotify(self):
        # Initialize Spotify Connect device
        self.spotify_connect = librespot.Session(
            username=None,  # Will be set via web interface
            password=None,  # Will be set via web interface
            name="Spotify Appliance",
            device_type=librespot.DeviceType.SPEAKER
        )
        
        # Get the device ID after connecting
        self.device_id = self.spotify_connect.device_id
        
        # Initialize Spotify Web API client
        self.spotify = Spotify(auth_manager=SpotifyOAuth(
            client_id="YOUR_CLIENT_ID",
            client_secret="YOUR_CLIENT_SECRET",
            redirect_uri="http://localhost:5000/callback",
            scope="user-modify-playback-state user-read-playback-state streaming"
        ))
        
    def start(self):
        self.initialize_spotify()
        while True:
            try:
                if not self.is_playing:
                    self.ensure_playback()
                time.sleep(1)
            except Exception as e:
                print(f"Playback error: {e}")
                time.sleep(5)
    
    def ensure_playback(self):
        if not self.current_track:
            # Start radio mode or default playlist
            self.spotify.start_playback(device_id=self.device_id)
            self.is_playing = True
    
    def reclaim_playback(self):
        """Force playback to this device"""
        if self.device_id:
            self.spotify.transfer_playback(device_id=self.device_id, force_play=True) 