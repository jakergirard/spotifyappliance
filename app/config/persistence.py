import json
import os

class ConfigStore:
    def __init__(self, config_path="/home/pi/spotify-appliance/instance/config.json"):
        self.config_path = config_path
        self.config = self.load_config()
    
    def load_config(self):
        if os.path.exists(self.config_path):
            with open(self.config_path, 'r') as f:
                return json.load(f)
        return {}
    
    def save_config(self):
        os.makedirs(os.path.dirname(self.config_path), exist_ok=True)
        with open(self.config_path, 'w') as f:
            json.dump(self.config, f)
    
    def get_spotify_credentials(self):
        return {
            'username': self.config.get('spotify_username'),
            'password': self.config.get('spotify_password')
        }
    
    def set_spotify_credentials(self, username, password):
        self.config['spotify_username'] = username
        self.config['spotify_password'] = password
        self.save_config() 