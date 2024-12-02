import alsaaudio

class AudioService:
    def __init__(self):
        try:
            # Try HiFiBerry's hardware mixer first
            self.mixer = alsaaudio.Mixer('Digital')
        except alsaaudio.ALSAAudioError:
            # Fall back to default PCM mixer
            self.mixer = alsaaudio.Mixer('PCM')
        
    def set_volume(self, volume: int):
        """Set volume level (0-100)"""
        # HiFiBerry DAC+ ADC Pro has a different volume range
        # Convert 0-100 to appropriate dB range (-103.5dB to 0dB)
        if self.mixer.mixer() == 'Digital':
            db_volume = (volume / 100.0) * 103.5 - 103.5
            self.mixer.setvolume(int(-db_volume * 2))
        else:
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