<#
.SYNOPSIS
    Script complet pour explorer et afficher les données du projet "Revoir-Histoire-Anciens-Batisseurs"
.DESCRIPTION
    Crée une interface web dynamique pour explorer tous les fichiers et dossiers du projet
    avec des pages dédiées pour chaque type de contenu (cartes, sources, documents)
.NOTES
    Version: 5.0
    Auteur: Expert en automatisation historique
    Date: 05/04/2025
#>

# Configuration initiale
$global:ProjectRoot = $PSScriptRoot
$global:LogFile = "$ProjectRoot\project_log_$(Get-Date -Format 'yyyyMMdd').txt"
$global:PythonExe = "python.exe"
$global:PipExe = "pip.exe"
$global:FlaskPort = 5000

# Structure du projet
$global:ProjectStructure = @{
    WebInterface = "$ProjectRoot\web_interface"
    Templates = "$ProjectRoot\web_interface\templates"
    Static = "$ProjectRoot\web_interface\static"
    Data = @{
        Maps = "$ProjectRoot\data\maps\raw_images\historical"
        Sources = "$ProjectRoot\data\sources"
        Links = "$ProjectRoot\Donnees_Lien_URL"
        Documents = "$ProjectRoot\docs"
    }
}

# Création de la structure nécessaire
function Initialize-ProjectStructure {
    # Dossiers web
    @($ProjectStructure.Templates, $ProjectStructure.Static) | ForEach-Object {
        if (-not (Test-Path $_)) {
            New-Item -ItemType Directory -Path $_ -Force | Out-Null
        }
    }

    # Sous-dossiers static
    @("css", "js", "images") | ForEach-Object {
        $dir = "$($ProjectStructure.Static)\$_"
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
    }
}

# Fonction pour scanner les fichiers du projet
function Get-ProjectFiles {
    $files = @{
        Maps = @()
        Sources = @()
        Links = @()
        Documents = @()
        Scripts = @()
        Other = @()
    }

    # Cartes historiques
    if (Test-Path $ProjectStructure.Data.Maps) {
        $files.Maps = Get-ChildItem -Path $ProjectStructure.Data.Maps -File | 
                      Select-Object Name, LastWriteTime, Length, @{Name="Path"; Expression={"maps/raw_images/historical/$($_.Name)"}}
    }

    # Sources de données
    if (Test-Path $ProjectStructure.Data.Sources) {
        $files.Sources = Get-ChildItem -Path $ProjectStructure.Data.Sources -File | 
                         Select-Object Name, LastWriteTime, Length, @{Name="Path"; Expression={"data/sources/$($_.Name)"}}
    }

    # Liens URL
    if (Test-Path $ProjectStructure.Data.Links) {
        $files.Links = Get-ChildItem -Path $ProjectStructure.Data.Links -File | 
                       Select-Object Name, LastWriteTime, Length, @{Name="Path"; Expression={"Donnees_Lien_URL/$($_.Name)"}}
    }

    # Documents
    if (Test-Path $ProjectStructure.Data.Documents) {
        $files.Documents = Get-ChildItem -Path $ProjectStructure.Data.Documents -File -Recurse | 
                          Select-Object Name, LastWriteTime, Length, @{Name="Path"; Expression={"docs/$($_.Name)"}}
    }

    # Scripts
    $scriptsPath = "$ProjectRoot\scripts"
    if (Test-Path $scriptsPath) {
        $files.Scripts = Get-ChildItem -Path $scriptsPath -File | 
                         Select-Object Name, LastWriteTime, Length, @{Name="Path"; Expression={"scripts/$($_.Name)"}}
    }

    # Autres fichiers
    $files.Other = Get-ChildItem -Path $ProjectRoot -File | 
                   Where-Object { $_.DirectoryName -notmatch "web_interface|data|docs|scripts" } |
                   Select-Object Name, LastWriteTime, Length, @{Name="Path"; Expression={"$($_.Name)"}}

    return $files
}

# Initialisation du contenu web
function Initialize-WebContent {
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
            <button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#navbarNav">
                <span class="navbar-toggler-icon"></span>
            </button>
            <div class="collapse navbar-collapse" id="navbarNav">
                <ul class="navbar-nav">
                    <li class="nav-item"><a class="nav-link" href="/">Accueil</a></li>
                    <li class="nav-item"><a class="nav-link" href="/cartes">Cartes</a></li>
                    <li class="nav-item"><a class="nav-link" href="/sources">Sources</a></li>
                    <li class="nav-item"><a class="nav-link" href="/liens">Liens</a></li>
                    <li class="nav-item"><a class="nav-link" href="/documents">Documents</a></li>
                    <li class="nav-item"><a class="nav-link" href="/scripts">Scripts</a></li>
                </ul>
            </div>
        </div>
    </nav>

    <main class="container my-4">
        {% with messages = get_flashed_messages() %}
            {% if messages %}
                {% for message in messages %}
                <div class="alert alert-info">{{ message }}</div>
                {% endfor %}
            {% endif %}
        {% endwith %}

        {% block content %}{% endblock %}
    </main>

    <footer class="bg-dark text-white py-3 mt-4">
        <div class="container text-center">
            <p>Projet de recherche historique &copy; 2025 - Tous droits réservés</p>
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
<div class="row">
    <div class="col-md-8 mx-auto text-center">
        <h1 class="display-4 mb-4">Exploration des données historiques</h1>
        <p class="lead">Découvrez notre collection complète de cartes, sources et documents sur les anciennes civilisations</p>
        
        <div class="row mt-5">
            {% for category, items in files.items() %}
            {% if items %}
            <div class="col-md-4 mb-4">
                <div class="card h-100">
                    <div class="card-body">
                        <h2>{{ category|capitalize }}</h2>
                        <p>{{ items|length }} éléments disponibles</p>
                        <a href="/{{ category }}" class="btn btn-primary">Explorer</a>
                    </div>
                </div>
            </div>
            {% endif %}
            {% endfor %}
        </div>
    </div>
</div>
{% endblock %}
"@

    # Fichier category.html (pour toutes les catégories)
    $categoryHtml = @"
{% extends "base.html" %}

{% block title %}{{ category|capitalize }} - Anciens Bâtisseurs{% endblock %}

{% block content %}
<div class="container">
    <h1 class="mb-4">{{ category|capitalize }}</h1>
    
    <div class="table-responsive">
        <table class="table table-striped">
            <thead>
                <tr>
                    <th>Nom</th>
                    <th>Dernière modification</th>
                    <th>Taille</th>
                    <th>Actions</th>
                </tr>
            </thead>
            <tbody>
                {% for file in files %}
                <tr>
                    <td>{{ file.Name }}</td>
                    <td>{{ file.LastWriteTime.strftime('%d/%m/%Y %H:%M') }}</td>
                    <td>{{ (file.Length/1024)|round(2) }} Ko</td>
                    <td>
                        <a href="/view/{{ file.Path }}" class="btn btn-sm btn-outline-primary">Voir</a>
                        <a href="/download/{{ file.Path }}" class="btn btn-sm btn-outline-secondary">Télécharger</a>
                    </td>
                </tr>
                {% endfor %}
            </tbody>
        </table>
    </div>
</div>
{% endblock %}
"@

    # Fichier styles.css
    $stylesCss = @"
body {
    font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
    background-color: #f8f9fa;
}

.navbar {
    box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}

.card {
    transition: transform 0.3s;
}

.card:hover {
    transform: translateY(-5px);
    box-shadow: 0 10px 20px rgba(0,0,0,0.1);
}

.table-responsive {
    background-color: white;
    border-radius: 8px;
    box-shadow: 0 2px 4px rgba(0,0,0,0.05);
}

.img-preview {
    max-width: 100%;
    height: auto;
    border-radius: 4px;
    box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}
"@

    # Création des fichiers
    $baseHtml | Out-File "$($ProjectStructure.Templates)\base.html" -Encoding UTF8
    $indexHtml | Out-File "$($ProjectStructure.Templates)\index.html" -Encoding UTF8
    $categoryHtml | Out-File "$($ProjectStructure.Templates)\category.html" -Encoding UTF8
    $stylesCss | Out-File "$($ProjectStructure.Static)\css\styles.css" -Encoding UTF8
}

# Fonction pour démarrer le serveur web
function Start-WebServer {
    $flaskApp = @"
from flask import Flask, render_template, send_from_directory, abort
import os
from datetime import datetime
import json

app = Flask(__name__)

# Configuration
PROJECT_ROOT = r'$ProjectRoot'
DEBUG_MODE = $true

# Routes principales
@app.route('/')
def index():
    files = {
        'maps': get_files(r'$($ProjectStructure.Data.Maps)'),
        'sources': get_files(r'$($ProjectStructure.Data.Sources)'),
        'links': get_files(r'$($ProjectStructure.Data.Links)'),
        'documents': get_files(r'$($ProjectStructure.Data.Documents)'),
        'scripts': get_files(os.path.join(PROJECT_ROOT, 'scripts'))
    }
    return render_template('index.html', files=files)

@app.route('/<category>')
def show_category(category):
    category_map = {
        'cartes': r'$($ProjectStructure.Data.Maps)',
        'sources': r'$($ProjectStructure.Data.Sources)',
        'liens': r'$($ProjectStructure.Data.Links)',
        'documents': r'$($ProjectStructure.Data.Documents)',
        'scripts': os.path.join(PROJECT_ROOT, 'scripts')
    }
    
    if category not in category_map:
        abort(404)
        
    path = category_map[category]
    files = get_files(path)
    return render_template('category.html', category=category, files=files)

@app.route('/view/<path:filepath>')
def view_file(filepath):
    full_path = os.path.join(PROJECT_ROOT, filepath)
    if not os.path.exists(full_path):
        abort(404)
        
    if filepath.endswith(('.jpg', '.jpeg', '.png', '.webp')):
        return render_template('view_image.html', image_path=filepath)
    else:
        try:
            with open(full_path, 'r', encoding='utf-8') as f:
                content = f.read()
            return render_template('view_text.html', content=content, filename=os.path.basename(filepath))
        except:
            return send_from_directory(os.path.dirname(full_path), os.path.basename(full_path))

@app.route('/download/<path:filepath>')
def download_file(filepath):
    full_path = os.path.join(PROJECT_ROOT, filepath)
    if not os.path.exists(full_path):
        abort(404)
    return send_from_directory(os.path.dirname(full_path), os.path.basename(full_path), as_attachment=True)

# Fonctions utilitaires
def get_files(path):
    if not os.path.exists(path):
        return []
    
    files = []
    for item in os.listdir(path):
        item_path = os.path.join(path, item)
        if os.path.isfile(item_path):
            stat = os.stat(item_path)
            files.append({
                'Name': item,
                'Path': os.path.relpath(item_path, PROJECT_ROOT).replace('\\', '/'),
                'LastWriteTime': datetime.fromtimestamp(stat.st_mtime),
                'Length': stat.st_size
            })
    return files

if __name__ == '__main__':
    app.run(port=$FlaskPort, debug=DEBUG_MODE)
"@

    # Fichiers templates supplémentaires
    $viewImageHtml = @"
{% extends "base.html" %}

{% block title %}Visualisation - {{ filename }}{% endblock %}

{% block content %}
<div class="container">
    <h1>{{ filename }}</h1>
    <div class="text-center mt-4">
        <img src="/{{ image_path }}" alt="{{ filename }}" class="img-fluid img-preview">
    </div>
</div>
{% endblock %}
"@

    $viewTextHtml = @"
{% extends "base.html" %}

{% block title %}Visualisation - {{ filename }}{% endblock %}

{% block content %}
<div class="container">
    <h1>{{ filename }}</h1>
    <div class="card mt-4">
        <div class="card-body">
            <pre><code>{{ content }}</code></pre>
        </div>
    </div>
</div>
{% endblock %}
"@

    # Création des fichiers supplémentaires
    $viewImageHtml | Out-File "$($ProjectStructure.Templates)\view_image.html" -Encoding UTF8
    $viewTextHtml | Out-File "$($ProjectStructure.Templates)\view_text.html" -Encoding UTF8
    $flaskApp | Out-File "$($ProjectStructure.WebInterface)\app.py" -Encoding UTF8

    Write-Host "Démarrage du serveur web sur http://localhost:$FlaskPort" -ForegroundColor Cyan
    Write-Host "Appuyez sur Ctrl+C pour arrêter le serveur" -ForegroundColor Yellow

    Push-Location $ProjectStructure.WebInterface
    & $PythonExe "app.py"
    Pop-Location
}

# Menu principal
function Show-MainMenu {
    Clear-Host
    Write-Host @"
=================================================================
 EXPLORATEUR DE DONNÉES - ANCIENS BATISSEURS - v5.0
=================================================================

1. Initialiser la structure du projet
2. Démarrer le serveur web
3. Installer les dépendances
4. Quitter

"@ -ForegroundColor Cyan

    $choice = Read-Host "Sélectionnez une option"
    
    switch ($choice) {
        "1" { 
            Initialize-ProjectStructure
            Initialize-WebContent
            Write-Host "Structure initialisée avec succès!" -ForegroundColor Green
            Pause
            Show-MainMenu 
        }
        "2" { 
            Start-WebServer
            Show-MainMenu 
        }
        "3" {
            Write-Host "Installation des dépendances..." -ForegroundColor Yellow
            & $PipExe install flask python-dotenv
            Write-Host "Dépendances installées avec succès!" -ForegroundColor Green
            Pause
            Show-MainMenu
        }
        "4" { exit }
        default { Show-MainMenu }
    }
}

# Point d'entrée
Initialize-ProjectStructure
Show-MainMenu