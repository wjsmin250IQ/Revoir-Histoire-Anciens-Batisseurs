<#
.SYNOPSIS
    Script de gestion complet pour le projet "Revoir-Histoire-Anciens-Batisseurs"
.DESCRIPTION
    Automatise l'installation, la conversion des données, l'analyse et la visualisation
    avec un focus sur l'amélioration du site web (structure, design, contenu)
.NOTES
    Version: 4.3
    Auteur: Expert en automatisation historique
    Date: 05/04/2025
#>

# Configuration initiale
$global:ProjectRoot = $PSScriptRoot
$global:LogFile = "$ProjectRoot\project_log_$(Get-Date -Format 'yyyyMMdd').txt"
$global:PythonExe = "python.exe"
$global:PipExe = "pip.exe"
$global:FlaskPort = 5000

# Structure complète du site web
$global:WebStructure = @{
    BaseDir = "$ProjectRoot\web_interface"
    Templates = "$ProjectRoot\web_interface\templates"
    Static = "$ProjectRoot\web_interface\static"
    CSS = "$ProjectRoot\web_interface\static\css"
    JS = "$ProjectRoot\web_interface\static\js"
    Images = "$ProjectRoot\web_interface\static\images"
    Fonts = "$ProjectRoot\web_interface\static\fonts"
}

# Création de la structure complète
function Initialize-ProjectStructure {
    Write-Host "Création de la structure du projet..." -ForegroundColor Cyan

    # Création de tous les répertoires nécessaires
    $WebStructure.Values | ForEach-Object {
        if (-not (Test-Path $_)) {
            New-Item -ItemType Directory -Path $_ -Force | Out-Null
            Write-Host "Créé: $_" -ForegroundColor Green
        }
    }

    # Vérification de la structure
    if (-not (Test-Path $WebStructure.Templates)) {
        throw "Échec de la création de la structure des templates"
    }

    Write-Host "Structure du projet initialisée avec succès!" -ForegroundColor Green
}

# Initialisation du contenu web complet
function Initialize-WebContent {
    param(
        [switch]$Force = $false
    )

    # Fichier base.html
    $baseHtml = @"
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{% block title %}Anciens Bâtisseurs{% endblock %}</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="/static/css/styles.css" rel="stylesheet">
    {% block extra_css %}{% endblock %}
</head>
<body>
    <nav class="navbar navbar-expand-lg navbar-dark bg-dark mb-4">
        <div class="container">
            <a class="navbar-brand" href="/">Anciens Bâtisseurs</a>
            <div class="collapse navbar-collapse">
                <ul class="navbar-nav me-auto">
                    <li class="nav-item"><a class="nav-link" href="/">Accueil</a></li>
                    <li class="nav-item"><a class="nav-link" href="/theories">Théories</a></li>
                    <li class="nav-item"><a class="nav-link" href="/cartes">Cartes</a></li>
                    <li class="nav-item"><a class="nav-link" href="/sources">Sources</a></li>
                    <li class="nav-item"><a class="nav-link" href="/apropos">À propos</a></li>
                </ul>
            </div>
        </div>
    </nav>

    <main class="container my-4">
        {% block content %}{% endblock %}
    </main>

    <footer class="bg-dark text-white py-3 mt-4">
        <div class="container text-center">
            <p>Projet de recherche historique &copy; 2025</p>
        </div>
    </footer>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
    {% block scripts %}{% endblock %}
</body>
</html>
"@

    # Fichier index.html
    $indexHtml = @"
{% extends "base.html" %}

{% block title %}Accueil - Anciens Bâtisseurs{% endblock %}

{% block content %}
<section class="hero mb-5">
    <div class="row">
        <div class="col-md-8">
            <h1 class="display-4">Bienvenue sur notre projet de recherche</h1>
            <p class="lead">Découvrez les mystères des anciennes civilisations</p>
        </div>
    </div>
</section>

<section class="features">
    <div class="row">
        <div class="col-md-4 mb-4">
            <div class="card h-100">
                <div class="card-body">
                    <h2>Théories</h2>
                    <p>Explorez nos analyses des anciennes constructions.</p>
                    <a href="/theories" class="btn btn-primary">Voir les théories</a>
                </div>
            </div>
        </div>
        <div class="col-md-4 mb-4">
            <div class="card h-100">
                <div class="card-body">
                    <h2>Cartes</h2>
                    <p>Collection de cartes historiques analysées.</p>
                    <a href="/cartes" class="btn btn-primary">Explorer</a>
                </div>
            </div>
        </div>
        <div class="col-md-4 mb-4">
            <div class="card h-100">
                <div class="card-body">
                    <h2>Sources</h2>
                    <p>Documents et références historiques.</p>
                    <a href="/sources" class="btn btn-primary">Consulter</a>
                </div>
            </div>
        </div>
    </div>
</section>
{% endblock %}
"@

    # Fichier styles.css
    $stylesCss = @"
:root {
    --primary-color: #2c3e50;
    --secondary-color: #34495e;
    --accent-color: #3498db;
}

body {
    font-family: 'Segoe UI', system-ui, sans-serif;
    line-height: 1.6;
    color: #333;
}

.navbar {
    box-shadow: 0 2px 10px rgba(0,0,0,0.1);
}

.hero {
    padding: 3rem 0;
    background-color: #f8f9fa;
    border-radius: 0.5rem;
}

.card {
    border: none;
    border-radius: 0.5rem;
    box-shadow: 0 0.125rem 0.25rem rgba(0,0,0,0.075);
    transition: transform 0.3s ease;
}

.card:hover {
    transform: translateY(-5px);
    box-shadow: 0 0.5rem 1rem rgba(0,0,0,0.15);
}

.btn-primary {
    background-color: var(--primary-color);
    border-color: var(--primary-color);
}

@media (max-width: 768px) {
    .hero {
        padding: 2rem 0;
    }
}
"@

    # Création des fichiers
    try {
        $baseHtml | Out-File "$($WebStructure.Templates)\base.html" -Encoding utf8 -Force:$Force
        $indexHtml | Out-File "$($WebStructure.Templates)\index.html" -Encoding utf8 -Force:$Force
        $stylesCss | Out-File "$($WebStructure.CSS)\styles.css" -Encoding utf8 -Force:$Force

        # Créer des pages vides pour les autres routes
        @("theories", "cartes", "sources", "apropos") | ForEach-Object {
            $content = @"
{% extends "base.html" %}

{% block title %}$($_ -replace '^.', { $_.Value.ToUpper() }) - Anciens Bâtisseurs{% endblock %}

{% block content %}
<div class="container">
    <h1>$($_ -replace '^.', { $_.Value.ToUpper() })</h1>
    <p>Contenu à venir...</p>
</div>
{% endblock %}
"@
            $content | Out-File "$($WebStructure.Templates)\$_.html" -Encoding utf8 -Force:$Force
        }

        Write-Host "Contenu web initialisé avec succès!" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Erreur lors de l'initialisation du contenu: $_" -ForegroundColor Red
        return $false
    }
}

# Fonction pour démarrer le serveur web avec vérification
function Start-WebServer {
    param(
        [int]$Port = $FlaskPort
    )

    # Vérifier que les templates existent
    if (-not (Test-Path "$($WebStructure.Templates)\index.html")) {
        Write-Host "Les templates n'existent pas. Initialisation..." -ForegroundColor Yellow
        Initialize-WebContent -Force
    }

    # Création du fichier app.py avec configuration correcte
    $flaskApp = @"
from flask import Flask, render_template
import os

app = Flask(__name__, template_folder='templates', static_folder='static')

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/theories')
def theories():
    return render_template('theories.html')

@app.route('/cartes')
def cartes():
    return render_template('cartes.html')

@app.route('/sources')
def sources():
    return render_template('sources.html')

@app.route('/apropos')
def apropos():
    return render_template('apropos.html')

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=$Port, debug=True)
"@

    try {
        # S'assurer qu'on est dans le bon répertoire
        if (-not (Test-Path $WebStructure.BaseDir)) {
            New-Item -ItemType Directory -Path $WebStructure.BaseDir -Force | Out-Null
        }

        Set-Location $WebStructure.BaseDir
        $flaskApp | Out-File "app.py" -Encoding utf8 -Force

        Write-Host "Démarrage du serveur web sur http://localhost:$Port" -ForegroundColor Cyan
        Write-Host "Appuyez sur Ctrl+C pour arrêter le serveur" -ForegroundColor Yellow

        & $PythonExe "app.py"
    }
    catch {
        Write-Host "Erreur lors du démarrage du serveur: $_" -ForegroundColor Red
    }
    finally {
        Set-Location $ProjectRoot
    }
}

# Menu principal amélioré
function Show-MainMenu {
    Clear-Host
    Write-Host @"
=================================================================
 GESTION DU PROJET - ANCIENS BATISSEURS - v4.3
=================================================================

1. Initialiser toute la structure du projet
2. Initialiser seulement le contenu web
3. Démarrer le serveur web
4. Installer les dépendances
5. Quitter

"@ -ForegroundColor Cyan

    $choice = Read-Host "Sélectionnez une option"
    
    switch ($choice) {
        "1" { 
            Initialize-ProjectStructure
            Initialize-WebContent -Force
            Pause
            Show-MainMenu 
        }
        "2" { 
            Initialize-WebContent -Force
            Pause
            Show-MainMenu 
        }
        "3" { 
            Start-WebServer
            Show-MainMenu 
        }
        "4" {
            Write-Host "Installation des dépendances Python..." -ForegroundColor Yellow
            & $PipExe install flask python-dotenv flask-sqlalchemy
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Dépendances installées avec succès!" -ForegroundColor Green
            } else {
                Write-Host "Erreur lors de l'installation des dépendances" -ForegroundColor Red
            }
            Pause
            Show-MainMenu
        }
        "5" { exit }
        default { Show-MainMenu }
    }
}

# Point d'entrée principal
try {
    Initialize-ProjectStructure
    Show-MainMenu
}
catch {
    Write-Host "Erreur critique: $_" -ForegroundColor Red
    Pause
}