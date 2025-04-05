<#
.SYNOPSIS
    Script de gestion complet pour le projet "Revoir-Histoire-Anciens-Batisseurs"
.DESCRIPTION
    Automatise l'installation, la conversion des données (via fonctions natives PowerShell et Python), l'analyse et la visualisation
.NOTES
    Version: 1.3
    Auteur: Expert en automatisation historique
    Date: 04/04/2025
#>

# Configuration initiale
$global:ProjectRoot = $PSScriptRoot
$global:LogFile = "$ProjectRoot\project_log_$(Get-Date -Format 'yyyyMMdd').txt"
$global:PythonExe = "C:\Python312\python.exe"
$global:PipExe = "C:\Python312\Scripts\pip.exe"
$global:FlaskPort = 5000

# Configuration environnement Python
$env:PYTHONHOME = $null
$env:PYTHONPATH = $null
$env:Path = "C:\Python312;C:\Python312\Scripts;" + $env:Path

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
if (-not (Test-Path $global:PythonExe)) {
    Write-Log "Python n'est pas installé dans C:\Python312\" -Level "ERROR"
    exit 1
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
# FONCTIONS EXISTANTES DU PROJET
# ==============================================
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
        
        if (-not (Test-Path "$ProjectRoot\requirements.txt")) {
            throw "Fichier requirements.txt introuvable"
        }
        
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
        [string]$OutputDir = "$ProjectRoot\data\sources",
        [switch]$UseNative = $true
    )
    
    try {
        Write-Log "Conversion des fichiers hérités..."
        
        if (-not (Test-Path $InputDir)) {
            throw "Répertoire source introuvable"
        }
        
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
        
        if ($UseNative) {
            # Conversion native PowerShell
            if (Test-Path "$InputDir\Donnees_Lien_URL_YouTube.txt") {
                Convert-Data -inputFile "$InputDir\Donnees_Lien_URL_YouTube.txt" `
                            -outputFile "$OutputDir\youtube.json" `
                            -dataType "youtube"
            }
            
            if (Test-Path "$InputDir\Donnees_Lien_URL_Google.txt") {
                Convert-Data -inputFile "$InputDir\Donnees_Lien_URL_Google.txt" `
                            -outputFile "$OutputDir\google.json" `
                            -dataType "web"
            }
        }
        else {
            # Conversion via script Python (méthode originale)
            if (Test-Path "$InputDir\Donnees_Lien_URL_YouTube.txt") {
                & $PythonExe "$ProjectRoot\scripts\convert_legacy.py" `
                    -i "$InputDir\Donnees_Lien_URL_YouTube.txt" `
                    -o "$OutputDir\youtube.json" `
                    -t "youtube"
            }
            
            if (Test-Path "$InputDir\Donnees_Lien_URL_Google.txt") {
                & $PythonExe "$ProjectRoot\scripts\convert_legacy.py" `
                    -i "$InputDir\Donnees_Lien_URL_Google.txt" `
                    -o "$OutputDir\google.json" `
                    -t "web"
            }
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
        
        & $PythonExe "$ProjectRoot\scripts\analyze.py" --full
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
        $socket = New-Object System.Net.Sockets.TcpClient
        $socket.Connect("localhost", $Port)
        $socket.Close()
        throw "Port $Port déjà utilisé"
        
        $flaskJob = Start-Job -ScriptBlock {
            param($path, $port)
            Set-Location $path
            & python -m flask run --port $port
        } -ArgumentList $ProjectRoot, $Port
        
        Start-Sleep -Seconds 5
        Start-Process "http://localhost:$Port"
        
        Write-Log "Interface web démarrée. Ctrl+C pour arrêter." -Level "SUCCESS"
        
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

# ==============================================
# MENU PRINCIPAL
# ==============================================
function Show-MainMenu {
    Clear-Host
    Write-Host @"
=================================================================
 GESTION PROJET 'REVOIR HISTOIRE ANCIENS BATISSEURS' - v1.3
=================================================================

1. Vérifier l'environnement
2. Installer les dépendances
3. Convertir les données héritées
4. Lancer l'analyse complète
5. Traiter les cartes historiques
6. Démarrer l'interface web
7. Tout exécuter (full pipeline)
8. Options avancées
Q. Quitter

"@

    $choice = Read-Host "Sélectionnez une option"
    
    switch ($choice) {
        "1" { Test-Environment; Pause; Show-MainMenu }
        "2" { Install-Dependencies; Pause; Show-MainMenu }
        "3" { 
            $method = Read-Host "Méthode (native/python) [native]"
            Convert-LegacyData -UseNative ($method -ne "python")
            Pause
            Show-MainMenu
        }
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
 OPTIONS AVANCÉES - v1.3
=================================================================

1. Convertir un fichier spécifique (PowerShell)
2. Convertir un fichier spécifique (Python)
3. Tester la conversion native
4. Retour au menu principal
Q. Quitter

"@

    $choice = Read-Host "Sélectionnez une option"
    
    switch ($choice) {
        "1" {
            $inputFile = Read-Host "Fichier d'entrée"
            $outputFile = Read-Host "Fichier de sortie"
            $dataType = Read-Host "Type (youtube/web)"
            Convert-Data -inputFile $inputFile -outputFile $outputFile -dataType $dataType
            Pause
            Show-AdvancedMenu
        }
        "2" {
            $inputFile = Read-Host "Fichier d'entrée"
            $outputFile = Read-Host "Fichier de sortie"
            $dataType = Read-Host "Type (youtube/web)"
            & $PythonExe "$ProjectRoot\scripts\convert_legacy.py" -i $inputFile -o $outputFile -t $dataType
            Pause
            Show-AdvancedMenu
        }
        "3" {
            # Test de conversion native
            $testFile = "$ProjectRoot\tests\test_links.txt"
            if (-not (Test-Path $testFile)) {
                @("https://youtube.com/video1", "https://youtube.com/video2") | Out-File $testFile
            }
            Convert-Data -inputFile $testFile -outputFile "$ProjectRoot\tests\test_output.json" -dataType "youtube"
            Pause
            Show-AdvancedMenu
        }
        "4" { Show-MainMenu }
        "Q" { exit }
        default { Show-AdvancedMenu }
    }
}

# Point d'entrée principal
if ($args.Count -gt 0) {
    # Mode ligne de commande
    switch ($args[0]) {
        "--install" { Install-Dependencies -Force }
        "--convert" { 
            if ($args.Count -ge 4) {
                Convert-Data -inputFile $args[1] -outputFile $args[2] -dataType $args[3]
            }
            else {
                Convert-LegacyData
            }
        }
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
            Write-Host "Usage: manage_project.ps1 [--install|--convert [input output type]|--analyze|--maps [task]|--web|--all]"
            exit 1
        }
    }
}
else {
    # Mode interactif
    Show-MainMenu
}