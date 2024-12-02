// Update status every second
setInterval(updateStatus, 1000);

async function updateStatus() {
    const response = await fetch('/api/status');
    const status = await response.json();
    
    updateNowPlaying(status.current_track);
    updateVolume(status.volume);
}

async function updateQueue() {
    const response = await fetch('/api/queue');
    const queue = await response.json();
    
    const queueList = document.getElementById('queue-list');
    queueList.innerHTML = queue.queue.map(track => `
        <div class="queue-item">
            ${track.name} - ${track.artists[0].name}
        </div>
    `).join('');
}

async function setVolume(value) {
    await fetch('/api/volume', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify({ volume: value })
    });
}

async function reclaimPlayback() {
    await fetch('/api/playback/reclaim', {
        method: 'POST'
    });
}

// Volume slider event listener
document.getElementById('volume').addEventListener('change', (e) => {
    setVolume(e.target.value);
}); 