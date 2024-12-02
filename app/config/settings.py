class Config:
    # Flask settings
    SECRET_KEY = 'dev-key-change-in-production'
    
    # Default settings
    SPOTIFY_CLIENT_ID = None
    SPOTIFY_CLIENT_SECRET = None
    SPOTIFY_REDIRECT_URI = 'http://localhost:5000/callback'
    DEFAULT_VOLUME = 70
    FORCE_MONO = True
    
    # Playback settings
    DEFAULT_PLAYLIST_URI = 'spotify:playlist:YOUR_DEFAULT_PLAYLIST'
    AUTO_RECLAIM_PLAYBACK = True
    RECLAIM_DELAY_SECONDS = 5 