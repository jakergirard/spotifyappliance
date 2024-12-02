from flask import Blueprint, jsonify, request, current_app, render_template
import logging

logger = logging.getLogger(__name__)
api_bp = Blueprint('api', __name__)

@api_bp.route('/', methods=['GET'])
def index():
    """Render main control interface"""
    return render_template('index.html')

@api_bp.route('/api/status', methods=['GET'])
def get_status():
    """Get current playback status"""
    try:
        playback_service = current_app.config['playback_service']
        audio_service = current_app.config['audio_service']
        current_playback = playback_service.spotify.current_playback()
        
        return jsonify({
            'is_playing': playback_service.is_playing,
            'current_track': current_playback if current_playback else None,
            'volume': audio_service.get_volume(),
            'device_id': playback_service.device_id
        })
    except Exception as e:
        logger.error(f"Failed to get status: {e}")
        return jsonify({'error': str(e)}), 500

@api_bp.route('/api/volume', methods=['POST'])
def set_volume():
    """Set volume level"""
    try:
        volume = request.json.get('volume', 70)
        audio_service = current_app.config['audio_service']
        audio_service.set_volume(volume)
        return jsonify({'success': True, 'volume': volume})
    except Exception as e:
        logger.error(f"Failed to set volume: {e}")
        return jsonify({'error': str(e)}), 500

@api_bp.route('/api/playback/reclaim', methods=['POST'])
def reclaim_playback():
    """Force playback to this device"""
    try:
        playback_service = current_app.config['playback_service']
        playback_service.reclaim_playback()
        return jsonify({'success': True})
    except Exception as e:
        logger.error(f"Failed to reclaim playback: {e}")
        return jsonify({'error': str(e)}), 500 