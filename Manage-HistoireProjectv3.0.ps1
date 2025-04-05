<#
.SYNOPSIS
    Script de gestion complet pour le projet "Revoir-Histoire-Anciens-Batisseurs"
.DESCRIPTION
    Automatise l'installation, la conversion des données, l'analyse et la visualisation
.NOTES
    Version: 1.4
    Auteur: Expert en automatisation historique
    Date: 04/04/2025
#>

# Configuration initiale
$global:ProjectRoot = $PSScriptRoot
$global:LogFile = "$ProjectRoot\project_log_$(Get-Date -Format 'yyyyMMdd').txt"
$global:PythonExe = "python.exe"
$global:PipExe = "pip.exe"
$global:FlaskPort = 5000

# Création des répertoires nécessaires
$requiredDirs = @(
    "$ProjectRoot\data",
    "$ProjectRoot\data\sources",
    "$ProjectRoot\data\maps",
    "$ProjectRoot\data\maps\raw_images",
    "$ProjectRoot\data\maps\raw_images\historical",
    "$ProjectRoot\tests"
)

foreach ($dir in $requiredDirs) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
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
        $modules = @("flask", "pandas", "pillow", "pytesseract")
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
                "python-dotenv>=0.19.0"
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
        
        # Démarrer Flask en arrière-plan
        $flaskScript = @"
from flask import Flask
app = Flask(__name__)

@app.route('/')
def home():
    return 'Interface du projet Revoir Histoire Anciens Batisseurs'

if __name__ == '__main__':
    app.run(port=$Port)
"@
        $flaskScript | Out-File "$ProjectRoot\app.py" -Encoding utf8
        
        $flaskJob = Start-Job -ScriptBlock {
            param($path, $port)
            Set-Location $path
            & python app.py
        } -ArgumentList $ProjectRoot, $Port
        
        # Attendre le démarrage
        Start-Sleep -Seconds 5
        
        # Ouvrir le navigateur
        Start-Process "http://localhost:$Port"
        
        Write-Log "Interface web démarrée sur http://localhost:$Port" -Level "SUCCESS"
        Write-Host "Appuyez sur Ctrl+C pour arrêter le serveur..." -ForegroundColor Yellow
        
        # Garder le script actif
        [System.Console]::TreatControlCAsInput = $true
        while ($true) {
            if ([System.Console]::KeyAvailable) {
                $key = [System.Console]::ReadKey($true)
                if (($key.Modifiers -band [System.ConsoleModifiers]::Control) -and ($key.Key -eq "C")) {
                    Write-Host "Arrêt du serveur..." -ForegroundColor Yellow
                    Stop-Job $flaskJob
                    Remove-Job $flaskJob
                    Remove-Item "$ProjectRoot\app.py" -ErrorAction SilentlyContinue
                    break
                }
            }
            Start-Sleep -Seconds 1
        }
        
        return $true
    }
    catch {
        Write-Log "Erreur de démarrage: $_" -Level "ERROR"
        if ($flaskJob) { 
            Stop-Job $flaskJob
            Remove-Job $flaskJob
        }
        Remove-Item "$ProjectRoot\app.py" -ErrorAction SilentlyContinue
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
 GESTION PROJET 'REVOIR HISTOIRE ANCIENS BATISSEURS' - v1.4
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
 OPTIONS AVANCÉES - v1.4
=================================================================

1. Convertir un fichier spécifique (PowerShell)
2. Convertir un fichier spécifique (Python)
3. Tester la conversion native
4. Réinitialiser l'environnement
5. Retour au menu principal
Q. Quitter

"@

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
        "5" { Show-MainMenu }
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