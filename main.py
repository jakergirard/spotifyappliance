import logging
from flask import Flask
from app.api.routes import api_bp
from app.services.playback import PlaybackService
from app.services.device_monitor import DeviceMonitor
from app.services.health import HealthMonitor
import threading

def setup_logging():
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        handlers=[
            logging.StreamHandler(),
            logging.FileHandler('/var/log/spotify-appliance.log')
        ]
    )

def create_app():
    setup_logging()
    logger = logging.getLogger('spotify-appliance')
    
    app = Flask(__name__, instance_relative_config=True)
    
    # Load configuration
    app.config.from_object('app.config.settings.Config')
    app.config.from_json('config.json', silent=True)
    
    # Initialize services
    health_monitor = HealthMonitor()
    playback_service = PlaybackService()
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
    app.register_blueprint(api_bp, url_prefix='/api')
    
    return app

if __name__ == '__main__':
    app = create_app()
    app.run(host='0.0.0.0', port=5000) 