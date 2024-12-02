from flask import Blueprint, jsonify, request, current_app
from app.services.playback import PlaybackService
from app.services.audio import AudioService

api_bp = Blueprint('api', __name__)

@api_bp.route('/status', methods=['GET'])
def get_status():
    playback_service = current_app.config['playback_service']
    audio_service = current_app.config['audio_service']
    current_playback = playback_service.spotify.current_playback()
    return jsonify({
        'is_playing': playback_service.is_playing,
        'current_track': current_playback if current_playback else None,
        'volume': audio_service.get_volume(),
        'device_id': playback_service.device_id
    })

@api_bp.route('/volume', methods=['POST'])
def set_volume():
    volume = request.json.get('volume', 70)
    audio_service.set_volume(volume)
    return jsonify({'success': True, 'volume': volume})

@api_bp.route('/queue', methods=['GET'])
def get_queue():
    queue = playback_service.spotify.queue()
    return jsonify(queue)

@api_bp.route('/queue/add', methods=['POST'])
def add_to_queue():
    track_uri = request.json.get('uri')
    playback_service.spotify.add_to_queue(track_uri, device_id=playback_service.device_id)
    return jsonify({'success': True})

@api_bp.route('/playback/reclaim', methods=['POST'])
def reclaim_playback():
    playback_service.reclaim_playback()
    return jsonify({'success': True})

@api_bp.route('/setup', methods=['POST'])
def setup_spotify():
    config_store = ConfigStore()
    username = request.json.get('username')
    password = request.json.get('password')
    
    if username and password:
        config_store.set_spotify_credentials(username, password)
        playback_service.initialize_spotify()
        return jsonify({'success': True})
    return jsonify({'success': False, 'error': 'Missing credentials'}) 