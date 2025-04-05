<#
.SYNOPSIS
    Script de gestion complet pour le projet "Revoir-Histoire-Anciens-Batisseurs"
.DESCRIPTION
    Automatise l'installation, la conversion des données, l'analyse et la visualisation
.NOTES
    Version: 4.0
    Auteur: Expert en automatisation historique
    Date: 04/04/2025
#>

# Configuration initiale
$global:ProjectRoot = $PSScriptRoot
$global:LogFile = "$ProjectRoot\project_log_$(Get-Date -Format 'yyyyMMdd').txt"
$global:PythonExe = "python.exe"
$global:PipExe = "pip.exe"
$global:FlaskPort = 5000
$global:WebAssetsDir = "$ProjectRoot\web_interface\static"

# Création des répertoires nécessaires
$requiredDirs = @(
    "$ProjectRoot\data",
    "$ProjectRoot\data\sources",
    "$ProjectRoot\data\maps",
    "$ProjectRoot\data\maps\raw_images",
    "$ProjectRoot\data\maps\raw_images\historical",
    "$ProjectRoot\tests",
    "$WebAssetsDir\css",
    "$WebAssetsDir\js",
    "$WebAssetsDir\images",
    "$ProjectRoot\web_interface\templates"
)

foreach ($dir in $requiredDirs) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

# Création des fichiers CSS/JS si inexistants
$cssContent = @"
/* Modern CSS for the project */
:root {
    --primary-color: #4a6fa5;
    --secondary-color: #166088;
    --accent-color: #4fc3f7;
    --dark-color: #1a2639;
    --light-color: #f0f4ef;
    --success-color: #28a745;
    --warning-color: #ffc107;
    --danger-color: #dc3545;
}

body {
    font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
    background-color: #f5f5f5;
    color: #333;
    line-height: 1.6;
}

.navbar {
    background-color: var(--dark-color) !important;
    box-shadow: 0 2px 10px rgba(0,0,0,0.1);
}

.navbar-brand {
    font-weight: 700;
    font-size: 1.5rem;
}

.card {
    border: none;
    border-radius: 8px;
    box-shadow: 0 4px 6px rgba(0,0,0,0.1);
    transition: transform 0.3s ease;
}

.card:hover {
    transform: translateY(-5px);
}

.btn-primary {
    background-color: var(--primary-color);
    border-color: var(--primary-color);
}

.btn-primary:hover {
    background-color: var(--secondary-color);
    border-color: var(--secondary-color);
}

.map-container {
    position: relative;
    overflow: hidden;
    padding-top: 56.25%; /* 16:9 Aspect Ratio */
}

.map-iframe {
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    border: none;
}

.analysis-result {
    background-color: white;
    border-left: 4px solid var(--accent-color);
    padding: 15px;
    margin-bottom: 20px;
}

.timeline {
    position: relative;
    padding-left: 50px;
}

.timeline::before {
    content: '';
    position: absolute;
    left: 20px;
    top: 0;
    bottom: 0;
    width: 2px;
    background-color: var(--accent-color);
}

.timeline-item {
    position: relative;
    margin-bottom: 30px;
}

.timeline-item::before {
    content: '';
    position: absolute;
    left: -40px;
    top: 5px;
    width: 20px;
    height: 20px;
    border-radius: 50%;
    background-color: var(--primary-color);
}

/* Dark mode support */
@media (prefers-color-scheme: dark) {
    body {
        background-color: #121212;
        color: #f5f5f5;
    }
    
    .card {
        background-color: #1e1e1e;
        color: #f5f5f5;
    }
    
    .analysis-result {
        background-color: #1e1e1e;
    }
}
"@

$jsContent = @"
// Modern JavaScript for interactive elements
document.addEventListener('DOMContentLoaded', function() {
    // Initialize tooltips
    $('[data-toggle="tooltip"]').tooltip();
    
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
            `<div class="col-md-4 mb-4">
                <div class="card map-thumbnail" data-map-id="${map.id}">
                    <img src="/static/images/maps/${map.thumbnail}" class="card-img-top" alt="${map.name}">
                    <div class="card-body">
                        <h5 class="card-title">${map.name}</h5>
                        <p class="card-text">${map.year}</p>
                    </div>
                </div>
            </div>`
        ).join('');
    }
}

function showFullMap(mapId) {
    // Show full map in modal
    $('#mapModal').modal('show');
    document.getElementById('map-modal-title').innerText = mapId;
    document.getElementById('map-modal-image').src = `/static/images/maps/full/${mapId}.jpg`;
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
    notification.className = `alert alert-${type} fixed-top mx-auto mt-3`;
    notification.style.width = '300px';
    notification.style.zIndex = '2000';
    notification.innerText = message;
    
    document.body.appendChild(notification);
    
    setTimeout(() => {
        notification.remove();
    }, 3000);
}
"@

# Créer les fichiers d'assets s'ils n'existent pas
if (-not (Test-Path "$WebAssetsDir\css\main.css")) {
    $cssContent | Out-File "$WebAssetsDir\css\main.css" -Encoding UTF8
}

if (-not (Test-Path "$WebAssetsDir\js\app.js")) {
    $jsContent | Out-File "$WebAssetsDir\js\app.js" -Encoding UTF8
}

# Configuration environnement Python
$env:PYTHONHOME = $null
$env:PYTHONPATH = $null

# Couleurs pour la sortie console
$global:ColorSuccess = "Green"
$global:ColorError = "Red"
$global:ColorWarning = "Yellow"
$global:ColorInfo = "Cyan"

# Fonction de logging améliorée
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp][$Level] $Message"
    
    Add-Content -Path $LogFile -Value $logEntry
    
    switch ($Level) {
        "SUCCESS" { Write-Host $logEntry -ForegroundColor $ColorSuccess }
        "ERROR"   { Write-Host $logEntry -ForegroundColor $ColorError }
        "WARNING" { Write-Host $logEntry -ForegroundColor $ColorWarning }
        default   { Write-Host $logEntry -ForegroundColor $ColorInfo }
    }
}

# Vérification de l'installation Python
function Test-PythonInstallation {
    try {
        $pythonVersion = & $PythonExe --version 2>&1
        if (-not ($pythonVersion -match "Python 3")) {
            throw "Python 3.x requis"
        }
        return $true
    }
    catch {
        Write-Log "Erreur Python: $_" -Level "ERROR"
        return $false
    }
}

# ==============================================
# FONCTION DE CONVERSION NATIVE POWERSHELL
# ==============================================
function Convert-Data {
    param(
        [Parameter(Mandatory=$true)][string]$inputFile,
        [Parameter(Mandatory=$true)][string]$outputFile,
        [Parameter(Mandatory=$true)][ValidateSet("youtube","web")][string]$dataType
    )

    try {
        # Vérifier si le fichier d'entrée existe
        if (-not (Test-Path -Path $inputFile)) {
            Write-Log "Le fichier $inputFile n'existe pas." -Level "ERROR"
            return $false
        }

        # Mapping des types de données
        $platformMap = @{
            "youtube" = "YouTube"
            "web" = "Web"
        }
        $platform = $platformMap[$dataType]

        # Lire le fichier d'entrée
        $lines = Get-Content -Path $inputFile -Encoding UTF8
        
        # Préparer les données pour la conversion JSON
        $data = @()
        foreach ($line in $lines) {
            $trimmedLine = $line.Trim()
            if (-not [string]::IsNullOrEmpty($trimmedLine)) {
                $data += @{
                    platform = $platform
                    url = $trimmedLine
                    timestamp = (Get-Date).ToString("o")
                    metadata = @{
                        processed = $false
                        notes = ""
                    }
                }
            }
        }

        # Convertir en JSON et sauvegarder
        $jsonData = $data | ConvertTo-Json -Depth 3
        [System.IO.File]::WriteAllText($outputFile, $jsonData, [System.Text.Encoding]::UTF8)

        Write-Log "Conversion réussie : $outputFile" -Level "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Erreur lors de la conversion : $_" -Level "ERROR"
        return $false
    }
}

# ==============================================
# FONCTIONS PRINCIPALES DU PROJET
# ==============================================
function Test-Environment {
    try {
        if (-not (Test-PythonInstallation)) {
            return $false
        }
        
        # Vérification des modules Python
        $modules = @("flask", "pandas", "pillow", "pytesseract", "flask_socketio", "flask_sqlalchemy")
        $missingModules = @()
        
        foreach ($module in $modules) {
            $check = & $PythonExe -c "try: import $module; print(True); except: print(False)" 2>&1
            if ($check -eq "False") {
                $missingModules += $module
            }
        }
        
        if ($missingModules.Count -gt 0) {
            throw "Modules manquants: " + ($missingModules -join ", ")
        }
        
        Write-Log "Environnement validé avec succès" -Level "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Erreur de configuration: $_" -Level "ERROR"
        return $false
    }
}

function Install-Dependencies {
    param(
        [switch]$Force = $false
    )
    
    try {
        Write-Log "Installation des dépendances Python..."
        
        # Création du fichier requirements.txt s'il n'existe pas
        if (-not (Test-Path "$ProjectRoot\requirements.txt")) {
            @(
                "flask>=2.0.0",
                "pandas>=1.3.0",
                "pillow>=9.0.0",
                "pytesseract>=0.3.8",
                "python-dotenv>=0.19.0",
                "flask-socketio>=5.0.0",
                "flask-sqlalchemy>=3.0.0",
                "eventlet>=0.30.0",
                "flask-bootstrap>=3.3.7.1"
            ) | Out-File "$ProjectRoot\requirements.txt"
        }
        
        $pipOutput = & $PipExe install -r "$ProjectRoot\requirements.txt" 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            throw $pipOutput
        }
        
        Write-Log "Dépendances installées avec succès" -Level "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Échec de l'installation: $_" -Level "ERROR"
        return $false
    }
}

function Convert-LegacyData {
    param(
        [string]$InputDir = "$ProjectRoot\Donnees_Lien_URL",
        [string]$OutputDir = "$ProjectRoot\data\sources",
        [switch]$UseNative = $true
    )
    
    try {
        Write-Log "Conversion des fichiers hérités..."
        
        # Création du répertoire source s'il n'existe pas
        if (-not (Test-Path $InputDir)) {
            New-Item -ItemType Directory -Path $InputDir | Out-Null
            Write-Log "Répertoire source créé : $InputDir" -Level "WARNING"
        }
        
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
        
        # Création de fichiers exemples s'ils n'existent pas
        $youtubeFile = "$InputDir\Donnees_Lien_URL_YouTube.txt"
        if (-not (Test-Path $youtubeFile)) {
            @(
                "https://youtube.com/watch?v=exemple1",
                "https://youtube.com/watch?v=exemple2"
            ) | Out-File $youtubeFile
        }
        
        $webFile = "$InputDir\Donnees_Lien_URL_Google.txt"
        if (-not (Test-Path $webFile)) {
            @(
                "https://example.com/page1",
                "https://example.com/page2"
            ) | Out-File $webFile
        }
        
        if ($UseNative) {
            # Conversion native PowerShell
            if (Test-Path $youtubeFile) {
                Convert-Data -inputFile $youtubeFile `
                            -outputFile "$OutputDir\youtube.json" `
                            -dataType "youtube"
            }
            
            if (Test-Path $webFile) {
                Convert-Data -inputFile $webFile `
                            -outputFile "$OutputDir\google.json" `
                            -dataType "web"
            }
        }
        else {
            # Conversion via script Python
            if (Test-Path $youtubeFile) {
                & $PythonExe "$ProjectRoot\scripts\convert_legacy.py" `
                    -i $youtubeFile `
                    -o "$OutputDir\youtube.json" `
                    -t "youtube"
            }
            
            if (Test-Path $webFile) {
                & $PythonExe "$ProjectRoot\scripts\convert_legacy.py" `
                    -i $webFile `
                    -o "$OutputDir\google.json" `
                    -t "web"
            }
        }
        
        Write-Log "Conversion terminée avec succès" -Level "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Erreur de conversion: $_" -Level "ERROR"
        return $false
    }
}

function Invoke-FullAnalysis {
    try {
        Write-Log "Lancement de l'analyse complète..."
        
        # Création d'une carte exemple si elle n'existe pas
        $mapFile = "$ProjectRoot\data\maps\raw_images\historical\1754_Tartaria_map.jpg"
        if (-not (Test-Path $mapFile)) {
            New-Item -ItemType Directory -Path "$ProjectRoot\data\maps\raw_images\historical" -Force | Out-Null
            [System.Drawing.Bitmap]::new(100, 100).Save($mapFile, [System.Drawing.Imaging.ImageFormat]::Jpeg)
            Write-Log "Fichier carte exemple créé" -Level "WARNING"
        }
        
        # Exécution des analyses
        & $PythonExe "$ProjectRoot\scripts\analyze.py" --full
        if ($LASTEXITCODE -ne 0) {
            throw "Erreur dans analyze.py"
        }
        
        & $PythonExe "$ProjectRoot\scripts\map_processor.py" --task all
        if ($LASTEXITCODE -ne 0) {
            throw "Erreur dans map_processor.py"
        }
        
        Write-Log "Analyse complétée avec succès" -Level "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Échec de l'analyse: $_" -Level "ERROR"
        return $false
    }
}

function Process-Maps {
    param(
        [ValidateSet("thumbnails", "ocr", "verify", "all")]
        [string]$Task = "all",
        [string]$Language = "fra"
    )
    
    try {
        Write-Log "Traitement des cartes historiques (Tâche: $Task)..."
        
        # Création d'une carte exemple si elle n'existe pas
        $mapFile = "$ProjectRoot\data\maps\raw_images\historical\1754_Tartaria_map.jpg"
        if (-not (Test-Path $mapFile)) {
            New-Item -ItemType Directory -Path "$ProjectRoot\data\maps\raw_images\historical" -Force | Out-Null
            [System.Drawing.Bitmap]::new(100, 100).Save($mapFile, [System.Drawing.Imaging.ImageFormat]::Jpeg)
            Write-Log "Fichier carte exemple créé" -Level "WARNING"
        }
        
        $args = @("$ProjectRoot\scripts\map_processor.py", "--task", $Task)
        
        if ($Task -eq "ocr") {
            $args += "--lang"
            $args += $Language
        }
        
        & $PythonExe $args
        
        if ($LASTEXITCODE -ne 0) {
            throw "Erreur pendant le traitement"
        }
        
        Write-Log "Traitement des cartes terminé" -Level "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Échec du traitement: $_" -Level "ERROR"
        return $false
    }
}

function Start-WebInterface {
    param(
        [int]$Port = $FlaskPort
    )
    
    try {
        # Vérification si le port est déjà utilisé
        try {
            $socket = New-Object System.Net.Sockets.TcpClient
            $socket.Connect("127.0.0.1", $Port)
            $socket.Close()
            throw "Port $Port déjà utilisé"
        }
        catch [System.Net.Sockets.SocketException] {
            # Le port est libre, on continue
        }
        
        # Création des templates HTML s'ils n'existent pas
        $baseHtml = @"
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{% block title %}Revoir Histoire Anciens Bâtisseurs{% endblock %}</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="/static/css/main.css" rel="stylesheet">
    {% block extra_css %}{% endblock %}
</head>
<body>
    <nav class="navbar navbar-expand-lg navbar-dark mb-4">
        <div class="container">
            <a class="navbar-brand" href="/">Revoir Histoire Anciens Bâtisseurs</a>
            <button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#navbarNav">
                <span class="navbar-toggler-icon"></span>
            </button>
            <div class="collapse navbar-collapse" id="navbarNav">
                <ul class="navbar-nav me-auto">
                    <li class="nav-item">
                        <a class="nav-link" href="/dashboard">Tableau de bord</a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="/sources">Sources</a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="/maps">Cartes historiques</a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="/analysis">Analyse</a>
                    </li>
                </ul>
                <div class="d-flex">
                    <button class="btn btn-outline-light me-2" id="darkModeToggle">
                        <i class="bi bi-moon-fill"></i>
                    </button>
                </div>
            </div>
        </div>
    </nav>

    <div class="container">
        {% block content %}{% endblock %}
    </div>

    <!-- Modal for Map View -->
    <div class="modal fade" id="mapModal" tabindex="-1">
        <div class="modal-dialog modal-xl">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title" id="map-modal-title">Carte historique</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                </div>
                <div class="modal-body">
                    <img id="map-modal-image" class="img-fluid" src="">
                </div>
            </div>
        </div>
    </div>

    <footer class="mt-5 py-3 bg-light">
        <div class="container text-center">
            <p class="mb-0">Projet Revoir Histoire Anciens Bâtisseurs &copy; 2025</p>
        </div>
    </footer>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/socket.io-client@4.0.0/dist/socket.io.min.js"></script>
    <script src="/static/js/app.js"></script>
    {% block extra_js %}{% endblock %}
</body>
</html>
"@

        $dashboardHtml = @"
{% extends "base.html" %}

{% block title %}Tableau de bord{% endblock %}

{% block content %}
<div class="row mb-4">
    <div class="col-md-8">
        <h1>Tableau de bord</h1>
        <p class="lead">Vue d'ensemble du projet</p>
    </div>
    <div class="col-md-4 text-end">
        <button class="btn btn-primary" onclick="startAnalysis('full')">
            Lancer l'analyse complète
        </button>
    </div>
</div>

<div class="row">
    <div class="col-md-4 mb-4">
        <div class="card h-100">
            <div class="card-body">
                <h5 class="card-title">Statistiques</h5>
                <div class="d-flex justify-content-between">
                    <div>
                        <h6>Sources</h6>
                        <p id="source-count">0</p>
                    </div>
                    <div>
                        <h6>Cartes</h6>
                        <p id="map-count">0</p>
                    </div>
                    <div>
                        <h6>Analyses</h6>
                        <p id="analysis-count">0</p>
                    </div>
                </div>
            </div>
        </div>
    </div>
    
    <div class="col-md-8 mb-4">
        <div class="card h-100">
            <div class="card-body">
                <h5 class="card-title">Activité récente</h5>
                <div class="timeline" id="recent-activity">
                    <!-- Timeline items will be added dynamically -->
                </div>
            </div>
        </div>
    </div>
</div>

<div class="row">
    <div class="col-12">
        <div class="card">
            <div class="card-body">
                <h5 class="card-title">Progression de l'analyse</h5>
                <div class="progress mb-3">
                    <div id="analysis-progress" class="progress-bar" role="progressbar" style="width: 0%"></div>
                </div>
                <p id="analysis-status">En attente de démarrage...</p>
            </div>
        </div>
    </div>
</div>
{% endblock %}
"@

        $mapsHtml = @"
{% extends "base.html" %}

{% block title %}Cartes historiques{% endblock %}

{% block extra_css %}
<style>
    .map-card {
        transition: transform 0.3s;
        cursor: pointer;
    }
    .map-card:hover {
        transform: scale(1.03);
    }
</style>
{% endblock %}

{% block content %}
<div class="row mb-4">
    <div class="col-md-8">
        <h1>Cartes historiques</h1>
        <p class="lead">Collection de cartes anciennes analysées</p>
    </div>
    <div class="col-md-4 text-end">
        <button class="btn btn-primary" onclick="startAnalysis('maps')">
            Analyser les cartes
        </button>
    </div>
</div>

<div class="row" id="maps-list">
    {% for map in maps %}
    <div class="col-md-4 mb-4">
        <div class="card map-card" onclick="showFullMap('{{ map.id }}')">
            <img src="/static/images/maps/{{ map.thumbnail }}" class="card-img-top" alt="{{ map.name }}">
            <div class="card-body">
                <h5 class="card-title">{{ map.name }}</h5>
                <p class="card-text">{{ map.description }}</p>
                <div class="d-flex justify-content-between">
                    <small class="text-muted">{{ map.year }}</small>
                    <span class="badge bg-{{ 'success' if map.processed else 'warning' }}">
                        {{ 'Traité' if map.processed else 'En attente' }}
                    </span>
                </div>
            </div>
        </div>
    </div>
    {% endfor %}
</div>
{% endblock %}
"@

        $sourcesHtml = @"
{% extends "base.html" %}

{% block title %}Sources documentaires{% endblock %}

{% block content %}
<div class="row mb-4">
    <div class="col-md-8">
        <h1>Sources documentaires</h1>
        <p class="lead">Références et matériaux de recherche</p>
    </div>
    <div class="col-md-4 text-end">
        <button class="btn btn-primary" onclick="startAnalysis('sources')">
            Analyser les sources
        </button>
    </div>
</div>

<div class="row">
    <div class="col-md-6 mb-4">
        <div class="card h-100">
            <div class="card-body">
                <h5 class="card-title">Sources YouTube</h5>
                <div class="list-group" id="youtube-sources">
                    {% for source in youtube_sources %}
                    <a href="{{ source.url }}" target="_blank" class="list-group-item list-group-item-action">
                        {{ source.url }}
                        <span class="badge bg-{{ 'success' if source.metadata.processed else 'secondary' }} float-end">
                            {{ 'Traité' if source.metadata.processed else 'Non traité' }}
                        </span>
                    </a>
                    {% endfor %}
                </div>
            </div>
        </div>
    </div>
    
    <div class="col-md-6 mb-4">
        <div class="card h-100">
            <div class="card-body">
                <h5 class="card-title">Sources Web</h5>
                <div class="list-group" id="web-sources">
                    {% for source in web_sources %}
                    <a href="{{ source.url }}" target="_blank" class="list-group-item list-group-item-action">
                        {{ source.url }}
                        <span class="badge bg-{{ 'success' if source.metadata.processed else 'secondary' }} float-end">
                            {{ 'Traité' if source.metadata.processed else 'Non traité' }}
                        </span>
                    </a>
                    {% endfor %}
                </div>
            </div>
        </div>
    </div>
</div>
{% endblock %}
"@

        # Créer les fichiers de template s'ils n'existent pas
        if (-not (Test-Path "$ProjectRoot\web_interface\templates\base.html")) {
            $baseHtml | Out-File "$ProjectRoot\web_interface\templates\base.html" -Encoding UTF8
        }
        
        if (-not (Test-Path "$ProjectRoot\web_interface\templates\dashboard.html")) {
            $dashboardHtml | Out-File "$ProjectRoot\web_interface\templates\dashboard.html" -Encoding UTF8
        }
        
        if (-not (Test-Path "$ProjectRoot\web_interface\templates\maps.html")) {
            $mapsHtml | Out-File "$ProjectRoot\web_interface\templates\maps.html" -Encoding UTF8
        }
        
        if (-not (Test-Path "$ProjectRoot\web_interface\templates\sources.html")) {
            $sourcesHtml | Out-File "$ProjectRoot\web_interface\templates\sources.html" -Encoding UTF8
        }

        # Démarrer Flask avec SocketIO
        $flaskScript = @"
from flask import Flask, render_template, jsonify
from flask_socketio import SocketIO
import threading
import time
import os
from datetime import datetime

app = Flask(__name__)
app.config['SECRET_KEY'] = 'secret!'
socketio = SocketIO(app, async_mode='eventlet')

# Simulated data
youtube_sources = []
web_sources = []
maps = []

def load_data():
    global youtube_sources, web_sources, maps
    
    # Load YouTube sources
    youtube_file = os.path.join(os.path.dirname(__file__), 'data', 'sources', 'youtube.json')
    if os.path.exists(youtube_file):
        import json
        with open(youtube_file, 'r', encoding='utf-8') as f:
            youtube_sources = json.load(f)
    
    # Load web sources
    web_file = os.path.join(os.path.dirname(__file__), 'data', 'sources', 'google.json')
    if os.path.exists(web_file):
        import json
        with open(web_file, 'r', encoding='utf-8') as f:
            web_sources = json.load(f)
    
    # Load maps data
    maps_dir = os.path.join(os.path.dirname(__file__), 'data', 'maps')
    if os.path.exists(maps_dir):
        for root, dirs, files in os.walk(maps_dir):
            for file in files:
                if file.lower().endswith(('.jpg', '.jpeg', '.png')):
                    map_name = os.path.splitext(file)[0]
                    maps.append({
                        'id': map_name,
                        'name': map_name.replace('_', ' ').title(),
                        'year': map_name.split('_')[0] if '_' in map_name else 'Inconnu',
                        'description': 'Carte historique de Tartaria',
                        'thumbnail': f"thumbnails/{file}",
                        'processed': True
                    })

def background_thread():
    """Example of how to send server generated events to clients."""
    count = 0
    while True:
        time.sleep(5)
        count += 1
        socketio.emit('update', {
            'time': datetime.now().strftime('%H:%M:%S'),
            'count': count,
            'analysis': {
                'progress': f"{min(count * 5, 100)}%",
                'status': "En cours" if count < 20 else "Terminé"
            },
            'maps': maps[:3]  # Send first 3 maps as example
        })

@app.route('/')
def index():
    return render_template('dashboard.html')

@app.route('/dashboard')
def dashboard():
    return render_template('dashboard.html')

@app.route('/sources')
def sources():
    return render_template('sources.html', 
                         youtube_sources=youtube_sources[:10],  # First 10 for demo
                         web_sources=web_sources[:10])

@app.route('/maps')
def maps_view():
    return render_template('maps.html', maps=maps[:6])  # First 6 for demo

@app.route('/api/analyze', methods=['POST'])
def analyze():
    import json
    data = json.loads(request.data)
    analysis_type = data.get('type', 'full')
    
    # In a real app, you would start the analysis process here
    return jsonify({
        'success': True,
        'message': f"Analyse {analysis_type} démarrée"
    })

@socketio.on('connect')
def handle_connect():
    print('Client connected')

@socketio.on('disconnect')
def handle_disconnect():
    print('Client disconnected')

if __name__ == '__main__':
    load_data()
    socketio.start_background_task(background_thread)
    socketio.run(app, port=$Port, debug=True)
"@

        $flaskScript | Out-File "$ProjectRoot\web_interface\app.py" -Encoding utf8
        
        Write-Host "Démarrage de l'interface web avancée..." -ForegroundColor Cyan
        Write-Host "Accédez à l'interface sur: http://localhost:$Port" -ForegroundColor Green
        Write-Host "Appuyez sur Ctrl+C pour arrêter le serveur" -ForegroundColor Yellow
        
        # Démarrer le serveur Flask avec SocketIO
        Push-Location "$ProjectRoot\web_interface"
        & $PythonExe "app.py"
        Pop-Location
        
        return $true
    }
    catch {
        Write-Log "Erreur de démarrage: $_" -Level "ERROR"
        return $false
    }
}

# ==============================================
# MENU PRINCIPAL
# ==============================================
function Show-MainMenu {
    Clear-Host
    Write-Host @"
=================================================================
 GESTION PROJET 'REVOIR HISTOIRE ANCIENS BATISSEURS' - v4.0
=================================================================

1. Vérifier l'environnement
2. Installer les dépendances
3. Convertir les données héritées
4. Lancer l'analyse complète
5. Traiter les cartes historiques
6. Démarrer l'interface web avancée
7. Tout exécuter (full pipeline)
8. Options avancées
Q. Quitter

"@ -ForegroundColor Cyan

    $choice = Read-Host "Sélectionnez une option"
    
    switch ($choice.ToUpper()) {
        "1" { 
            $result = Test-Environment
            if (-not $result) {
                Write-Host "`nSolution: Exécutez l'option 2 pour installer les dépendances manquantes" -ForegroundColor Yellow
            }
            Pause
            Show-MainMenu 
        }
        "2" { 
            $result = Install-Dependencies
            if ($result) {
                Write-Host "`nSolution: Re-vérifiez l'environnement (option 1) après installation" -ForegroundColor Green
            }
            Pause
            Show-MainMenu 
        }
        "3" { 
            $method = Read-Host "Méthode (native/python) [native]"
            $result = Convert-LegacyData -UseNative ($method -ne "python")
            if (-not $result) {
                Write-Host "`nSolution: Vérifiez que les fichiers sources existent dans Donnees_Lien_URL" -ForegroundColor Yellow
            }
            Pause
            Show-MainMenu 
        }
        "4" { 
            $result = Invoke-FullAnalysis
            if (-not $result) {
                Write-Host "`nSolution: Vérifiez les fichiers de données et les dépendances" -ForegroundColor Yellow
            }
            Pause
            Show-MainMenu 
        }
        "5" { 
            $task = Read-Host "Tâche (thumbnails/ocr/verify/all) [all]"
            if (-not $task) { $task = "all" }
            $lang = if ($task -eq "ocr") { Read-Host "Langue (fra/eng) [fra]" } else { "fra" }
            if (-not $lang) { $lang = "fra" }
            $result = Process-Maps -Task $task -Language $lang
            if (-not $result) {
                Write-Host "`nSolution: Vérifiez les fichiers de cartes dans data\maps\raw_images" -ForegroundColor Yellow
            }
            Pause
            Show-MainMenu 
        }
        "6" { 
            $result = Start-WebInterface
            if (-not $result) {
                Write-Host "`nSolution: Vérifiez que le port $FlaskPort est libre et que Flask est installé" -ForegroundColor Yellow
            }
            Show-MainMenu 
        }
        "7" {
            if (Test-Environment) {
                Install-Dependencies -Force
                Convert-LegacyData
                Invoke-FullAnalysis
                Process-Maps -Task "all"
                Start-WebInterface
            }
        }
        "8" {
            Show-AdvancedMenu
        }
        "Q" { exit }
        default { Show-MainMenu }
    }
}

function Show-AdvancedMenu {
    Clear-Host
    Write-Host @"
=================================================================
 OPTIONS AVANCÉES - v4.0
=================================================================

1. Convertir un fichier spécifique (PowerShell)
2. Convertir un fichier spécifique (Python)
3. Tester la conversion native
4. Réinitialiser l'environnement
5. Générer des données de démo
6. Retour au menu principal
Q. Quitter

"@ -ForegroundColor Magenta

    $choice = Read-Host "Sélectionnez une option"
    
    switch ($choice.ToUpper()) {
        "1" {
            $inputFile = Read-Host "Chemin du fichier d'entrée"
            $outputFile = Read-Host "Chemin du fichier de sortie"
            $dataType = Read-Host "Type de données (youtube/web)"
            
            if ([string]::IsNullOrEmpty($inputFile) -or [string]::IsNullOrEmpty($outputFile) -or [string]::IsNullOrEmpty($dataType)) {
                Write-Host "Tous les paramètres sont obligatoires" -ForegroundColor Red
                Pause
                Show-AdvancedMenu
                return
            }
            
            $result = Convert-Data -inputFile $inputFile -outputFile $outputFile -dataType $dataType
            if (-not $result) {
                Write-Host "`nSolution: Vérifiez les chemins et les permissions" -ForegroundColor Yellow
            }
            Pause
            Show-AdvancedMenu
        }
        "2" {
            $inputFile = Read-Host "Chemin du fichier d'entrée"
            $outputFile = Read-Host "Chemin du fichier de sortie"
            $dataType = Read-Host "Type de données (youtube/web)"
            
            if ([string]::IsNullOrEmpty($inputFile) -or [string]::IsNullOrEmpty($outputFile) -or [string]::IsNullOrEmpty($dataType)) {
                Write-Host "Tous les paramètres sont obligatoires" -ForegroundColor Red
                Pause
                Show-AdvancedMenu
                return
            }
            
            try {
                & $PythonExe "$ProjectRoot\scripts\convert_legacy.py" -i $inputFile -o $outputFile -t $dataType
                if ($LASTEXITCODE -ne 0) {
                    throw "Erreur lors de la conversion Python"
                }
                Write-Log "Conversion Python réussie" -Level "SUCCESS"
            }
            catch {
                Write-Log "Échec de la conversion Python: $_" -Level "ERROR"
                Write-Host "`nSolution: Vérifiez que convert_legacy.py existe et que Python est correctement configuré" -ForegroundColor Yellow
            }
            Pause
            Show-AdvancedMenu
        }
        "3" {
            # Test de conversion native
            $testDir = "$ProjectRoot\tests"
            if (-not (Test-Path $testDir)) {
                New-Item -ItemType Directory -Path $testDir | Out-Null
            }
            
            $testFile = "$testDir\test_links.txt"
            @("https://youtube.com/watch?v=test1", "https://youtube.com/watch?v=test2") | Out-File $testFile -Force
            
            $result = Convert-Data -inputFile $testFile -outputFile "$testDir\test_output.json" -dataType "youtube"
            if ($result) {
                Write-Host "Test réussi - Fichier créé: $testDir\test_output.json" -ForegroundColor Green
            }
            else {
                Write-Host "`nSolution: Vérifiez les permissions d'écriture dans le dossier tests" -ForegroundColor Yellow
            }
            Pause
            Show-AdvancedMenu
        }
        "4" {
            Write-Host "Cette option va réinitialiser les dossiers de données et tests" -ForegroundColor Yellow
            $confirm = Read-Host "Êtes-vous sûr? (O/N)"
            if ($confirm -eq "O") {
                Remove-Item "$ProjectRoot\data" -Recurse -Force -ErrorAction SilentlyContinue
                Remove-Item "$ProjectRoot\tests" -Recurse -Force -ErrorAction SilentlyContinue
                Write-Log "Environnement réinitialisé" -Level "SUCCESS"
                Write-Host "Les dossiers data et tests ont été réinitialisés" -ForegroundColor Green
            }
            Pause
            Show-AdvancedMenu
        }
        "5" {
            Write-Host "Génération de données de démo..." -ForegroundColor Cyan
            
            # Générer des données de démo pour l'interface web
            $demoData = @{
                youtube = @(
                    @{
                        url = "https://youtube.com/watch?v=tartaria1"
                        timestamp = (Get-Date).ToString("o")
                        metadata = @{
                            processed = $true
                            notes = "Vidéo sur la Tartaria"
                        }
                    },
                    @{
                        url = "https://youtube.com/watch?v=ancient-builders"
                        timestamp = (Get-Date).AddDays(-1).ToString("o")
                        metadata = @{
                            processed = $false
                            notes = ""
                        }
                    }
                )
                web = @(
                    @{
                        url = "https://ancients-origins.com/tartaria"
                        timestamp = (Get-Date).AddDays(-2).ToString("o")
                        metadata = @{
                            processed = $true
                            notes = "Article de référence"
                        }
                    }
                )
            }
            
            $demoData.youtube | ConvertTo-Json -Depth 3 | Out-File "$ProjectRoot\data\sources\youtube.json" -Encoding UTF8
            $demoData.web | ConvertTo-Json -Depth 3 | Out-File "$ProjectRoot\data\sources\google.json" -Encoding UTF8
            
            Write-Host "Données de démo générées avec succès" -ForegroundColor Green
            Pause
            Show-AdvancedMenu
        }
        "6" { Show-MainMenu }
        "Q" { exit }
        default { Show-AdvancedMenu }
    }
}

# Point d'entrée principal
if ($args.Count -gt 0) {
    # Mode ligne de commande
    switch ($args[0].ToLower()) {
        "--install" { exit (Install-Dependencies -Force) ? 0 : 1 }
        "--convert" { 
            if ($args.Count -ge 4) {
                exit (Convert-Data -inputFile $args[1] -outputFile $args[2] -dataType $args[3]) ? 0 : 1
            }
            else {
                exit (Convert-LegacyData) ? 0 : 1
            }
        }
        "--analyze" { exit (Invoke-FullAnalysis) ? 0 : 1 }
        "--maps" { 
            $task = if ($args.Count -gt 1) { $args[1] } else { "all" }
            $lang = if ($args.Count -gt 2) { $args[2] } else { "fra" }
            exit (Process-Maps -Task $task -Language $lang) ? 0 : 1
        }
        "--web" { exit (Start-WebInterface) ? 0 : 1 }
        "--all" {
            if (Test-Environment) {
                $success = $true
                $success = $success -and (Install-Dependencies -Force)
                $success = $success -and (Convert-LegacyData)
                $success = $success -and (Invoke-FullAnalysis)
                $success = $success -and (Process-Maps -Task "all")
                $success = $success -and (Start-WebInterface)
                exit ($success) ? 0 : 1
            }
            exit 1
        }
        default {
            Write-Host "Usage: manage_project.ps1 [--install|--convert [input output type]|--analyze|--maps [task]|--web|--all]"
            exit 1
        }
    }
}
else {
    # Mode interactif
    Write-Host "Initialisation du projet..." -ForegroundColor Cyan
    Show-MainMenu
}