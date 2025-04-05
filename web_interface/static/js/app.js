document.addEventListener('DOMContentLoaded', function() { 
    // Initialisation des tooltips
    $('[data-toggle="tooltip"]').tooltip();

    // Mise à jour en temps réel des données via EventSource (push depuis le serveur)
    if (typeof(EventSource) !== "undefined") {
        const eventSource = new EventSource("/updates");
        
        // Gérer la réception des messages
        eventSource.onmessage = function(event) {
            const data = JSON.parse(event.data);
            updateDashboard(data);
        };
    }

    // Interaction avec les éléments de la carte (miniatures de cartes)
    const mapElements = document.querySelectorAll('.map-thumbnail');
    mapElements.forEach(map => {
        map.addEventListener('click', function() {
            showFullMap(this.dataset.mapId);
        });
    });

    // Désactivation du copier-coller pour des raisons de sécurité
    document.getElementById('password').addEventListener('paste', function(e) {
        e.preventDefault();
        alert('Le copier-coller est désactivé pour des raisons de sécurité.');
    });

    // Ajout de la fonctionnalité de chargement paresseux des cartes
    const images = document.querySelectorAll('img[data-src]');
    const observer = new IntersectionObserver((entries, observer) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                const img = entry.target;
                img.src = img.dataset.src;
                img.removeAttribute('data-src');
                observer.unobserve(img);
            }
        });
    }, { threshold: 0.1 });

    images.forEach(image => observer.observe(image));
});

// Fonction pour mettre à jour le tableau de bord avec de nouvelles données
function updateDashboard(data) {
    // Mettre à jour le progrès de l'analyse
    if (data.analysis) {
        document.getElementById('analysis-progress').innerText = data.analysis.progress;
        document.getElementById('analysis-status').innerText = data.analysis.status;
    }
    
    // Mettre à jour les cartes
    if (data.maps) {
        const mapsList = document.getElementById('maps-list');
        mapsList.innerHTML = data.maps.map(map => 
            `<div class="col-md-4 mb-4">
                <div class="card map-thumbnail" data-map-id="${map.id}">
                    <img data-src="/static/images/maps/${map.image}" class="card-img-top lazy-load" alt="${map.title}">
                    <div class="card-body">
                        <h5 class="card-title">${map.title}</h5>
                        <p class="card-text">${map.description}</p>
                    </div>
                </div>
            </div>`
        ).join('');
    }
}

// Fonction pour afficher la carte complète dans une fenêtre modale
function showFullMap(mapId) {
    $('#mapModal').modal('show');
    document.getElementById('map-modal-title').innerText = mapId;
    document.getElementById('map-modal-image').src = `/static/images/maps/full/${mapId}.jpg`;
    document.getElementById('map-modal-image').classList.add('zoom-effect');
}

// Fonction AJAX pour démarrer l'analyse et envoyer des notifications en fonction de l'état
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
        showNotification(data.message, data.success ? 'success' : 'error', data.success);
    });
}

// Fonction pour afficher des notifications contextuelles
function showNotification(message, type, success) {
    const notification = document.createElement('div');
    notification.className = `alert alert-${type} fixed-top mx-auto mt-3`;
    notification.style.width = '300px';
    notification.style.zIndex = '2000';
    notification.innerText = message;

    if (success) {
        const actionButton = document.createElement('button');
        actionButton.className = 'btn btn-link';
        actionButton.innerText = 'Réessayer';
        actionButton.onclick = () => { location.reload(); }; // Réessayer en rechargeant la page
        notification.appendChild(actionButton);
    }
    
    document.body.appendChild(notification);
    
    // Suppression de la notification après 5 secondes
    setTimeout(() => {
        notification.remove();
    }, 5000);
}

// Fonction d'animation pour le zoom sur la carte
document.getElementById('map-modal-image').addEventListener('click', function() {
    this.classList.toggle('zoom-effect');
});

// Fonction pour améliorer la sécurité côté client en échappant les caractères spéciaux
function escapeHtml(unsafe) {
    return unsafe.replace(/[&<>"'`=\/]/g, function (match) {
        return `&#${match.charCodeAt(0)};`;
    });
}
