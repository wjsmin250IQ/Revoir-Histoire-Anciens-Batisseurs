<#
.SYNOPSIS
    Script d'exploration complète pour le projet "Revoir-Histoire-Anciens-Batisseurs"
.DESCRIPTION
    Analyse TOUS les fichiers et dossiers du projet et les intègre dans une interface web organisée
.NOTES
    Version: 5.2
    Auteur: Expert en automatisation historique
    Date: 05/04/2025
#>

# Configuration initiale
$global:ProjectRoot = $PSScriptRoot
$global:PythonExe = "python.exe"
$global:PipExe = "pip.exe"
$global:FlaskPort = 5000

# Structure des dossiers clés (basée sur votre arborescence)
$global:ProjectPaths = @{
    WebInterface = "$ProjectRoot\web_interface"
    Templates    = "$ProjectRoot\web_interface\templates"
    Static       = "$ProjectRoot\web_interface\static"
    Data = @{
        Maps    = "$ProjectRoot\data\maps\raw_images\historical"
        Sources = "$ProjectRoot\data\sources"
        Links   = "$ProjectRoot\Donnees_Lien_URL"
        Docs    = "$ProjectRoot\docs"
        Scripts = "$ProjectRoot\scripts"
    }
}

# -------------------------------------------------------------------
# FONCTION : Scanner TOUS les fichiers du projet
# -------------------------------------------------------------------
function Get-AllProjectFiles {
    $allFiles = @()

    # Dossiers principaux
    $foldersToScan = @(
        $ProjectPaths.Data.Maps,
        $ProjectPaths.Data.Sources,
        $ProjectPaths.Data.Links,
        $ProjectPaths.Data.Docs,
        $ProjectPaths.Data.Scripts,
        "$ProjectRoot\config",
        "$ProjectRoot\templates",
        "$ProjectRoot\statics",
        "$ProjectRoot\tests"
    )

    # Fichiers racine
    Get-ChildItem -Path $ProjectRoot -File | ForEach-Object {
        $allFiles += [PSCustomObject]@{
            Name     = $_.Name
            Path     = $_.FullName.Replace($ProjectRoot, "").Trim("\")
            Category = "Root"
            Type     = if ($_.Extension) { $_.Extension.Trim('.') } else { "Unknown" }
            Size     = "$([math]::Round($_.Length / 1KB, 2)) Ko"
            Modified = $_.LastWriteTime.ToString("dd/MM/yyyy HH:mm")
        }
    }

    # Fichiers dans les dossiers
    foreach ($folder in $foldersToScan) {
        if (Test-Path $folder) {
            Get-ChildItem -Path $folder -Recurse -File | ForEach-Object {
                $category = switch -Wildcard ($_.DirectoryName) {
                    "*maps*"       { "Maps" }
                    "*sources*"    { "Sources" }
                    "*Donnees_Lien*" { "Links" }
                    "*docs*"       { "Documents" }
                    "*scripts*"    { "Scripts" }
                    default        { "Other" }
                }

                $allFiles += [PSCustomObject]@{
                    Name     = $_.Name
                    Path     = $_.FullName.Replace($ProjectRoot, "").Trim("\")
                    Category = $category
                    Type     = if ($_.Extension) { $_.Extension.Trim('.') } else { "Unknown" }
                    Size     = "$([math]::Round($_.Length / 1KB, 2)) Ko"
                    Modified = $_.LastWriteTime.ToString("dd/MM/yyyy HH:mm")
                }
            }
        }
    }

    return $allFiles
}

# -------------------------------------------------------------------
# FONCTION : Générer l'interface web Flask
# -------------------------------------------------------------------
function Initialize-WebInterface {
    # Création des dossiers nécessaires
    @($ProjectPaths.Templates, $ProjectPaths.Static) | ForEach-Object {
        if (-not (Test-Path $_)) { New-Item -ItemType Directory -Path $_ -Force | Out-Null }
    }

    # Fichier base.html
    $baseHtml = @"
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{% block title %}Explorateur de données{% endblock %}</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.10.0/font/bootstrap-icons.css" rel="stylesheet">
    <style>
        .file-icon {
            width: 24px;
            height: 24px;
            margin-right: 8px;
        }
        .category-badge {
            font-size: 0.8em;
        }
        .img-preview {
            max-height: 500px;
            width: auto;
        }
        .data-table th {
            background-color: #f8f9fa;
        }
        .link-item {
            border-left: 4px solid #0d6efd;
        }
        .hidden-structure {
            display: none;
        }
    </style>
</head>
<body>
    <nav class="navbar navbar-expand-lg navbar-dark bg-dark mb-4">
        <div class="container">
            <a class="navbar-brand" href="/">
                <img src="https://cdn-icons-png.flaticon.com/512/2232/2232688.png" width="30" height="30" class="d-inline-block align-top" alt="">
                Explorateur de données
            </a>
            <div class="collapse navbar-collapse">
                <ul class="navbar-nav me-auto">
                    <li class="nav-item"><a class="nav-link" href="/">Tous les fichiers</a></li>
                    <li class="nav-item"><a class="nav-link" href="/category/Maps">Cartes</a></li>
                    <li class="nav-item"><a class="nav-link" href="/category/Sources">Sources</a></li>
                    <li class="nav-item"><a class="nav-link" href="/category/Links">Liens</a></li>
                    <li class="nav-item"><a class="nav-link" href="/category/Documents">Documents</a></li>
                </ul>
            </div>
        </div>
    </nav>

    <div class="container">
        {% block content %}{% endblock %}
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>
"@

    

    # Fichier category.html
    $categoryHtml = @"
{% extends "base.html" %}

{% block title %}Fichiers {{ category }}{% endblock %}

{% block content %}
<div class="mb-4">
    <h1>Fichiers {{ category }}</h1>
    <p class="text-muted">{{ files|length }} fichiers trouvés</p>
</div>

<div class="row">
    {% for file in files %}
    <div class="col-md-4 mb-4">
        <div class="card h-100">
            <div class="card-body">
                <h5 class="card-title">
                    <img src="{{ url_for('static', filename='icons/' ~ file.Type ~ '.png') }}" 
                         onerror="this.src='{{ url_for('static', filename='icons/file.png') }}'" 
                         class="file-icon">
                    {{ file.Name }}
                </h5>
                <p class="card-text">
                    <small class="text-muted">{{ file.Type|upper }} • {{ file.Size }} • {{ file.Modified }}</small>
                </p>
            </div>
            <div class="card-footer bg-transparent">
                <a href="/view/{{ file.Path }}" class="btn btn-sm btn-outline-primary">Voir</a>
                <a href="/download/{{ file.Path }}" class="btn btn-sm btn-outline-secondary">Télécharger</a>
            </div>
        </div>
    </div>
    {% endfor %}
</div>
{% endblock %}
"@

    # Fichier view_file.html
    $viewFileHtml = @"
{% extends "base.html" %}

{% block title %}Visualisation - {{ file.Name }}{% endblock %}

{% block content %}
<div class="card">
    <div class="card-header">
        <h2>{{ file.Name }}</h2>
        <p class="mb-0">
            <span class="badge bg-secondary">{{ file.Category }}</span>
            <span class="badge bg-info text-dark">{{ file.Type|upper }}</span>
            <span class="text-muted">{{ file.Size }} • {{ file.Modified }}</span>
        </p>
    </div>
    
    <div class="card-body">
        {% if file.Type in ['jpg', 'jpeg', 'png', 'webp'] %}
        <div class="text-center">
            <img src="/{{ file.Path }}" alt="{{ file.Name }}" class="img-fluid img-preview">
        </div>
        
        {% elif file.Type == 'json' %}
        <div class="table-responsive">
            <table class="table table-bordered data-table">
                <tbody>
                    {% for key, value in content.items() %}
                    <tr>
                        <th>{{ key }}</th>
                        <td>
                            {% if value is iterable and value is not string %}
                                {{ value|join(", ") }}
                            {% else %}
                                {{ value }}
                            {% endif %}
                        </td>
                    </tr>
                    {% endfor %}
                </tbody>
            </table>
        </div>
        
        {% elif file.Type == 'csv' %}
        <div class="table-responsive">
            <table class="table table-bordered data-table">
                <thead>
                    <tr>
                        {% for header in content[0].keys() %}
                        <th>{{ header }}</th>
                        {% endfor %}
                    </tr>
                </thead>
                <tbody>
                    {% for row in content %}
                    <tr>
                        {% for value in row.values() %}
                        <td>{{ value }}</td>
                        {% endfor %}
                    </tr>
                    {% endfor %}
                </tbody>
            </table>
        </div>
        
        {% elif file.Type in ['txt', 'md'] %}
        <div class="list-group">
            {% for line in content.split('\n') %}
                {% if line.strip() and not line.startswith('#') and not line.startswith('//') %}
                <div class="list-group-item">{{ line }}</div>
                {% endif %}
            {% endfor %}
        </div>
        
        {% else %}
        <div class="alert alert-info">
            Ce type de fichier ne peut pas être prévisualisé directement.
        </div>
        <a href="/download/{{ file.Path }}" class="btn btn-primary">Télécharger le fichier</a>
        {% endif %}
    </div>
</div>
{% endblock %}
"@

   

    # Création du fichier app.py
    $flaskApp = @"
from flask import Flask, render_template, send_from_directory, abort
import os
from datetime import datetime
import json
import csv

app = Flask(__name__)

# Charger tous les fichiers
def load_all_files():
    files = []
    root_path = r'$ProjectRoot'
    
    # Parcourir tous les fichiers du projet
    for dirpath, dirnames, filenames in os.walk(root_path):
        # Ignorer certains dossiers
        if 'web_interface' in dirpath or '.git' in dirpath:
            continue
            
        for filename in filenames:
            full_path = os.path.join(dirpath, filename)
            rel_path = os.path.relpath(full_path, root_path)
            
            # Déterminer la catégorie
            category = "Other"
            if 'data\\maps' in dirpath: category = "Maps"
            elif 'data\\sources' in dirpath: category = "Sources"
            elif 'Donnees_Lien_URL' in dirpath: category = "Links"
            elif 'docs' in dirpath: category = "Documents"
            elif 'scripts' in dirpath: category = "Scripts"
            
            # Obtenir les métadonnées
            stat = os.stat(full_path)
            file_ext = os.path.splitext(filename)[1][1:].lower() if os.path.splitext(filename)[1] else "unknown"
            
            files.append({
                "Name": filename,
                "Path": rel_path.replace('\\', '/'),
                "Category": category,
                "Type": file_ext,
                "Size": f"{round(stat.st_size / 1024, 2)} Ko",
                "Modified": datetime.fromtimestamp(stat.st_mtime).strftime("%d/%m/%Y %H:%M")
            })
    
    return files

# Routes
@app.route('/')
def index():
    return render_template('index.html', files=load_all_files())

@app.route('/category/<category>')
def show_category(category):
    files = [f for f in load_all_files() if f["Category"].lower() == category.lower()]
    return render_template('category.html', category=category, files=files)

@app.route('/view/<path:filepath>')
def view_file(filepath):
    root_path = r'$ProjectRoot'
    full_path = os.path.join(root_path, filepath)
    
    if not os.path.exists(full_path):
        abort(404)
    
    # Trouver le fichier dans la liste
    file_data = next((f for f in load_all_files() if f["Path"] == filepath), None)
    if not file_data:
        abort(404)
    
    # Lire le contenu selon le type de fichier
    content = ""
    processed_content = None
    
    try:
        if file_data["Type"] == "json":
            with open(full_path, "r", encoding="utf-8") as f:
                content = json.load(f)
                
        elif file_data["Type"] == "csv":
            with open(full_path, "r", encoding="utf-8") as f:
                content = list(csv.DictReader(f))
                
        elif file_data["Type"] in ["txt", "md"]:
            with open(full_path, "r", encoding="utf-8") as f:
                content = f.read()
                
        elif file_data["Type"] in ["jpg", "jpeg", "png", "webp"]:
            content = None  # Les images sont gérées directement dans le template
                
    except Exception as e:
        content = f"[Erreur de lecture: {str(e)}]"
    
    return render_template('view_file.html', 
                         file=file_data, 
                         content=content)

@app.route('/download/<path:filepath>')
def download_file(filepath):
    root_path = r'$ProjectRoot'
    full_path = os.path.join(root_path, filepath)
    
    if not os.path.exists(full_path):
        abort(404)
        
    return send_from_directory(
        os.path.dirname(full_path),
        os.path.basename(full_path),
        as_attachment=True
    )

if __name__ == '__main__':
    app.run(port=$FlaskPort, debug=True)
"@

    $flaskApp | Out-File "$($ProjectPaths.WebInterface)\app.py" -Encoding UTF8
}

# -------------------------------------------------------------------
# FONCTION : Démarrer le serveur web
# -------------------------------------------------------------------
function Start-WebServer {
    Write-Host "Démarrage du serveur web sur http://localhost:$FlaskPort" -ForegroundColor Cyan
    Write-Host "Appuyez sur Ctrl+C pour arrêter" -ForegroundColor Yellow
    
    Push-Location $ProjectPaths.WebInterface
    try {
        & $PythonExe "app.py"
    }
    finally {
        Pop-Location
    }
}

# -------------------------------------------------------------------
# MENU PRINCIPAL
# -------------------------------------------------------------------
function Show-MainMenu {
    Clear-Host
    Write-Host @"
=================================================================
 EXPLORATEUR DE DONNÉES - ANCIENS BATISSEURS (v5.2)
=================================================================

1. Initialiser l'interface web
2. Démarrer le serveur web
3. Afficher les fichiers trouvés
4. Quitter

"@ -ForegroundColor Cyan

    $choice = Read-Host "Sélectionnez une option"
    
    switch ($choice) {
        "1" { 
            Initialize-WebInterface
            Write-Host "Interface web initialisée avec succès!" -ForegroundColor Green
            Pause
            Show-MainMenu 
        }
        "2" { 
            Start-WebServer
            Show-MainMenu 
        }
        "3" {
            $files = Get-AllProjectFiles
            $files | Format-Table Name, Category, Type, Size, Modified -AutoSize
            Write-Host "$($files.Count) fichiers trouvés" -ForegroundColor Green
            Pause
            Show-MainMenu
        }
        "4" { exit }
        default { Show-MainMenu }
    }
}

# Point d'entrée
Show-MainMenu