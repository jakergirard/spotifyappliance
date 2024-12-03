import alsaaudio
import logging

logger = logging.getLogger(__name__)

class AudioService:
    def __init__(self):
        try:
            self.mixer = alsaaudio.Mixer('Digital')
            logger.info("Using HiFiBerry Digital mixer")
            logger.info(f"Available mixers: {alsaaudio.mixers()}")
        except alsaaudio.ALSAAudioError as e:
            logger.warning(f"Failed to initialize Digital mixer: {e}")
            try:
                self.mixer = alsaaudio.Mixer('PCM')
                logger.info("Using PCM mixer")
            except alsaaudio.ALSAAudioError as e:
                logger.error(f"Failed to initialize audio mixer: {e}")
                raise
        
    def set_volume(self, volume: int):
        """Set volume level (0-100)"""
        try:
            if self.mixer.mixer() == 'Digital':
                # HiFiBerry DAC+ ADC Pro uses a different volume range
                db_volume = (volume / 100.0) * 103.5 - 103.5
                self.mixer.setvolume(int(-db_volume * 2))
            else:
                self.mixer.setvolume(volume)
            logger.debug(f"Volume set to {volume}")
        except Exception as e:
            logger.error(f"Failed to set volume: {e}")
            raise
        
    def get_volume(self) -> int:
        """Get current volume level"""
        try:
            return self.mixer.getvolume()[0]
        except Exception as e:
            logger.error(f"Failed to get volume: {e}")
            raise
    
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