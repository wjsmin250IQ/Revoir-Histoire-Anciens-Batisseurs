<#
.SYNOPSIS
    Script de gestion complet pour le projet "Revoir-Histoire-Anciens-Batisseurs"
.DESCRIPTION
    Automatise l'installation, la conversion des données, l'analyse et la visualisation
.NOTES
    Version: 1.2
    Auteur: Expert en automatisation historique
    Date: 04/04/2025
#>

# Configuration initiale
$global:ProjectRoot = $PSScriptRoot
$global:LogFile = "$ProjectRoot\project_log_$(Get-Date -Format 'yyyyMMdd').txt"
$global:PythonExe = "python"
$global:FlaskPort = 5000

# Couleurs pour la sortie console
$global:ColorSuccess = "Green"
$global:ColorError = "Red"
$global:ColorWarning = "Yellow"
$global:ColorInfo = "Cyan"

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

function Test-Environment {
    try {
        # Vérification de Python
        $pythonVersion = & $PythonExe --version 2>&1
        if (-not ($pythonVersion -match "Python 3")) {
            throw "Python 3.x requis"
        }
        
        # Vérification des modules Python
        $modules = @("flask", "pandas", "pillow", "pytesseract")
        foreach ($module in $modules) {
            $check = & $PythonExe -c "import $module" 2>&1
            if ($check -match "ModuleNotFoundError") {
                throw "Module $module manquant"
            }
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
        
        # Vérifier si le fichier requirements existe
        if (-not (Test-Path "$ProjectRoot\requirements.txt")) {
            throw "Fichier requirements.txt introuvable"
        }
        
        # Installation via pip
        $pipOutput = & $PythonExe -m pip install -r "$ProjectRoot\requirements.txt" 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            throw $pipOutput
        }
        
        Write-Log "Dépendances installées avec succès" -Level "SUCCESS"
    }
    catch {
        Write-Log "Échec de l'installation: $_" -Level "ERROR"
        exit 1
    }
}

function Convert-LegacyData {
    param(
        [string]$InputDir = "$ProjectRoot\Donnees_Lien URL",
        [string]$OutputDir = "$ProjectRoot\data\sources"
    )
    
    try {
        Write-Log "Conversion des fichiers hérités..."
        
        if (-not (Test-Path $InputDir)) {
            throw "Répertoire source introuvable"
        }
        
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
        
        # Conversion des fichiers YouTube
        if (Test-Path "$InputDir\Donnees_Lien_URL_YouTube.txt") {
            & $PythonExe "$ProjectRoot\scripts\convert_legacy.py" `
                -i "$InputDir\Donnees_Lien_URL_YouTube.txt" `
                -o "$OutputDir\youtube.json" `
                -t "youtube"
        }
        
        # Conversion des fichiers Google
        if (Test-Path "$InputDir\Donnees_Lien_URL_Google.txt") {
            & $PythonExe "$ProjectRoot\scripts\convert_legacy.py" `
                -i "$InputDir\Donnees_Lien_URL_Google.txt" `
                -o "$OutputDir\google.json" `
                -t "web"
        }
        
        Write-Log "Conversion terminée avec succès" -Level "SUCCESS"
    }
    catch {
        Write-Log "Erreur de conversion: $_" -Level "ERROR"
    }
}

function Invoke-FullAnalysis {
    try {
        Write-Log "Lancement de l'analyse complète..."
        
        # Analyse principale
        & $PythonExe "$ProjectRoot\scripts\analyze.py" --full
        
        # Traitement des cartes
        & $PythonExe "$ProjectRoot\scripts\map_processor.py" --task all
        
        if ($LASTEXITCODE -ne 0) {
            throw "Erreur lors de l'analyse"
        }
        
        Write-Log "Analyse complétée avec succès" -Level "SUCCESS"
    }
    catch {
        Write-Log "Échec de l'analyse: $_" -Level "ERROR"
    }
}

function Start-WebInterface {
    param(
        [int]$Port = $FlaskPort
    )
    
    try {
        Write-Log "Démarrage de l'interface web sur le port $Port..."
        
        # Vérifier si le port est disponible
        $portInUse = Test-NetConnection -ComputerName localhost -Port $Port -InformationLevel Quiet
        
        if ($portInUse) {
            throw "Le port $Port est déjà utilisé"
        }
        
        # Démarrer Flask en arrière-plan
        $flaskJob = Start-Job -ScriptBlock {
            param($path, $port)
            Set-Location $path
            & python -m flask run --port $port
        } -ArgumentList $ProjectRoot, $Port
        
        # Attendre le démarrage
        Start-Sleep -Seconds 5
        
        # Ouvrir le navigateur
        Start-Process "http://localhost:$Port"
        
        Write-Log "Interface web démarrée. Ctrl+C pour arrêter." -Level "SUCCESS"
        
        # Garder le script actif
        while ($true) {
            Start-Sleep -Seconds 1
        }
    }
    catch {
        Write-Log "Erreur de démarrage: $_" -Level "ERROR"
        if ($flaskJob) { Stop-Job $flaskJob }
        exit 1
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
    }
    catch {
        Write-Log "Échec du traitement: $_" -Level "ERROR"
    }
}

# Menu principal
function Show-MainMenu {
    Clear-Host
    Write-Host @"
=================================================================
 GESTION PROJET 'REVOIR HISTOIRE ANCIENS BATISSEURS' - v1.2
=================================================================

1. Vérifier l'environnement
2. Installer les dépendances
3. Convertir les données héritées
4. Lancer l'analyse complète
5. Traiter les cartes historiques
6. Démarrer l'interface web
7. Tout exécuter (full pipeline)
Q. Quitter

"@

    $choice = Read-Host "Sélectionnez une option"
    
    switch ($choice) {
        "1" { Test-Environment; Pause; Show-MainMenu }
        "2" { Install-Dependencies; Pause; Show-MainMenu }
        "3" { Convert-LegacyData; Pause; Show-MainMenu }
        "4" { Invoke-FullAnalysis; Pause; Show-MainMenu }
        "5" { 
            $task = Read-Host "Tâche (thumbnails/ocr/verify/all)"
            $lang = if ($task -eq "ocr") { Read-Host "Langue (fra/eng)" } else { "fra" }
            Process-Maps -Task $task -Language $lang
            Pause
            Show-MainMenu
        }
        "6" { Start-WebInterface; Show-MainMenu }
        "7" {
            if (Test-Environment) {
                Install-Dependencies -Force
                Convert-LegacyData
                Invoke-FullAnalysis
                Process-Maps -Task "all"
                Start-WebInterface
            }
        }
        "Q" { exit }
        default { Show-MainMenu }
    }
}

# Point d'entrée principal
if ($args.Count -gt 0) {
    # Mode ligne de commande
    switch ($args[0]) {
        "--install" { Install-Dependencies -Force }
        "--convert" { Convert-LegacyData }
        "--analyze" { Invoke-FullAnalysis }
        "--maps" { 
            $task = if ($args.Count -gt 1) { $args[1] } else { "all" }
            $lang = if ($args.Count -gt 2) { $args[2] } else { "fra" }
            Process-Maps -Task $task -Language $lang
        }
        "--web" { Start-WebInterface }
        "--all" {
            if (Test-Environment) {
                Install-Dependencies -Force
                Convert-LegacyData
                Invoke-FullAnalysis
                Process-Maps -Task "all"
                Start-WebInterface
            }
        }
        default {
            Write-Host "Usage: manage_project.ps1 [--install|--convert|--analyze|--maps [task]|--web|--all]"
            exit 1
        }
    }
}
else {
    # Mode interactif
    Show-MainMenu
}