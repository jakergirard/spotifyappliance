import alsaaudio

class AudioService:
    def __init__(self):
        self.mixer = alsaaudio.Mixer('PCM')
        
    def set_volume(self, volume: int):
        """Set volume level (0-100)"""
        self.mixer.setvolume(volume)
        
    def get_volume(self) -> int:
        """Get current volume level"""
        return self.mixer.getvolume()[0]
    
    def setup_mono_output(self):
        """Configure system for mono audio output"""
        try:
            # Create/modify .asoundrc file for mono output
            asoundrc = """
            pcm.mono {
                type route
                slave.pcm "default"
                ttable.0.0 0.5
                ttable.1.0 0.5
            }
            
            pcm.!default {
                type plug
                slave.pcm "mono"
            }
            """
            with open('/home/pi/.asoundrc', 'w') as f:
                f.write(asoundrc)
        except Exception as e:
            print(f"Error setting up mono output: {e}") 