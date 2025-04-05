// Modern JavaScript for interactive elements
document.addEventListener('DOMContentLoaded', function() {
    // Initialize tooltips
    [data-toggle="tooltip"].tooltip();
    
    // Real-time data updates
    if (typeof(EventSource) !== "undefined") {
        const eventSource = new EventSource("/updates");
        
        eventSource.onmessage = function(event) {
            const data = JSON.parse(event.data);
            updateDashboard(data);
        };
    }
    
    // Map interaction
    const mapElements = document.querySelectorAll('.map-thumbnail');
    mapElements.forEach(map => {
        map.addEventListener('click', function() {
            showFullMap(this.dataset.mapId);
        });
    });
});

function updateDashboard(data) {
    // Update various dashboard elements with new data
    if (data.analysis) {
        document.getElementById('analysis-progress').innerText = data.analysis.progress;
        document.getElementById('analysis-status').innerText = data.analysis.status;
    }
    
    if (data.maps) {
        const mapsList = document.getElementById('maps-list');
        mapsList.innerHTML = data.maps.map(map => 
            <div class="col-md-4 mb-4">
                <div class="card map-thumbnail" data-map-id="">
                    <img src="/static/images/maps/" class="card-img-top" alt="">
                    <div class="card-body">
                        <h5 class="card-title"></h5>
                        <p class="card-text"></p>
                    </div>
                </div>
            </div>
        ).join('');
    }
}

function showFullMap(mapId) {
    // Show full map in modal
    #mapModal.modal('show');
    document.getElementById('map-modal-title').innerText = mapId;
    document.getElementById('map-modal-image').src = /static/images/maps/full/.jpg;
}

// AJAX functions for interactive analysis
function startAnalysis(analysisType) {
    fetch('/api/analyze', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify({type: analysisType}),
    })
    .then(response => response.json())
    .then(data => {
        showNotification(data.message, data.success ? 'success' : 'error');
    });
}

function showNotification(message, type) {
    const notification = document.createElement('div');
    notification.className = lert alert- fixed-top mx-auto mt-3;
    notification.style.width = '300px';
    notification.style.zIndex = '2000';
    notification.innerText = message;
    
    document.body.appendChild(notification);
    
    setTimeout(() => {
        notification.remove();
    }, 3000);
}
