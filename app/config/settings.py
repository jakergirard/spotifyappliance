class Config:
    # Flask settings
    SECRET_KEY = 'your-secret-key'  # Change this in production
    
    # Spotify settings
    SPOTIFY_CLIENT_ID = 'YOUR_CLIENT_ID'
    SPOTIFY_CLIENT_SECRET = 'YOUR_CLIENT_SECRET'
    SPOTIFY_REDIRECT_URI = 'http://localhost:5000/callback'
    
    # Audio settings
    DEFAULT_VOLUME = 70
    FORCE_MONO = True
    
    # Playback settings
    DEFAULT_PLAYLIST_URI = 'spotify:playlist:YOUR_DEFAULT_PLAYLIST'
    AUTO_RECLAIM_PLAYBACK = True
    RECLAIM_DELAY_SECONDS = 5 