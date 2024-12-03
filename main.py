import logging
import json
from flask import Flask
from app.api.routes import api_bp
from app.services.playback import PlaybackService
from app.services.device_monitor import DeviceMonitor
from app.services.health import HealthMonitor
from app.services.audio import AudioService
import threading

def setup_logging():
    log_file = '/var/log/spotify-appliance.log'
    
    # Ensure log file exists and is writable
    try:
        with open(log_file, 'a'):
            pass
    except IOError:
        # Fall back to stdout only if we can't write to the log file
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        )
        return
    
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        handlers=[
            logging.StreamHandler(),
            logging.FileHandler(log_file)
        ]
    )

def create_app():
    setup_logging()
    logger = logging.getLogger('spotify-appliance')
    
    app = Flask(__name__, 
        instance_path='/opt/spotify-appliance/instance',
        template_folder='app/templates')
    
    # Load base configuration
    app.config.from_object('app.config.settings.Config')
    
    # Load instance configuration if it exists
    try:
        with open('/opt/spotify-appliance/instance/config.json', 'r') as f:
            app.config.update(json.loads(f.read()))
    except (FileNotFoundError, json.JSONDecodeError) as e:
        logger.warning(f"Could not load instance config: {e}")
    
    # Initialize services
    playback_service = PlaybackService()
    audio_service = AudioService()
    
    # Make services available to routes
    app.config['playback_service'] = playback_service
    app.config['audio_service'] = audio_service
    
    health_monitor = HealthMonitor()
    device_monitor = DeviceMonitor(playback_service)
    
    # Start background services with error handling
    def start_services():
        try:
            health_monitor.start()
            playback_service.start()
            device_monitor.start()
        except Exception as e:
            logger.error(f"Error starting services: {e}")
            raise
    
    threading.Thread(target=start_services, daemon=True).start()
    
    # Register blueprints
    app.register_blueprint(api_bp)
    
    return app

if __name__ == '__main__':
    app = create_app()
    app.run(host='0.0.0.0', port=5000) 