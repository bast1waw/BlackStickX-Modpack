# =================================================================
# BLACKSTICKX MODPACK AUTOMATED INSTALLER & MANAGEMENT TOOL
# Target Environment: Windows 10 / Windows 11
# Supported Shell: PowerShell 5.0+
# =================================================================

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# -----------------------------------------------------------------
# GLOBAL PATHS & CONFIGURATION
# -----------------------------------------------------------------
$MinecraftDir  = Join-Path $env:APPDATA ".minecraft"
$VersionsDir   = Join-Path $MinecraftDir "versions"
$ForgeVersion  = "1.20.1-47.4.22"
$ForgeTargetID = "1.20.1-forge-47.4.22"
$LogPath       = Join-Path $env:TEMP "BlackStickXInstaller.log"
$WorkDir       = Join-Path $env:TEMP "BlackStickX_Setup"

# Core Modpack Directories to Manage
$ModpackFolders = @("mods", "config", "defaultconfigs", "kubejs", "resourcepacks", "shaderpacks")

# Specific Targets for the Strict Update Subsystem (Only Mods & Config)
$UpdateFolders = @("mods", "config")

# Download URLs Manifest
$Downloads = @{
    "Config"        = "https://github.com/bast1waw/BlackStickX-Modpack/releases/download/v1.0.0/config.zip";
    "Defaultconfigs"= "https://github.com/bast1waw/BlackStickX-Modpack/releases/download/v1.0.0/defaultconfigs.zip";
    "Forge"         = "https://github.com/bast1waw/BlackStickX-Modpack/releases/download/v1.0.0/forge-1.20.1-47.4.22-installer.jar";
    "Java18"        = "https://github.com/bast1waw/BlackStickX-Modpack/releases/download/v1.0.0/jdk-18.0.2.1_windows-x64_bin.exe";
    "Java21"        = "https://github.com/bast1waw/BlackStickX-Modpack/releases/download/v1.0.0/jdk-21.0.11_windows-x64_bin.exe";
    "KubeJS"        = "https://github.com/bast1waw/BlackStickX-Modpack/releases/download/v1.0.0/kubejs.zip";
    "Manifest"      = "https://github.com/bast1waw/BlackStickX-Modpack/releases/download/v1.0.0/manifest.json";
    "Mods"          = "https://github.com/bast1waw/BlackStickX-Modpack/releases/download/v1.0.0/mods.zip";
    "Resourcepacks" = "https://github.com/bast1waw/BlackStickX-Modpack/releases/download/v1.0.0/resourcepacks.zip";
    "ServersDat"    = "https://github.com/bast1waw/BlackStickX-Modpack/releases/download/v1.0.0/servers.dat";
    "Shaderpacks"   = "https://github.com/bast1waw/BlackStickX-Modpack/releases/download/v1.0.0/shaderpacks.zip";
    "SKLauncherJar" = "https://github.com/bast1waw/BlackStickX-Modpack/releases/download/v1.0.0/SKlauncher-3.2.18.jar";
    "SKLauncherExe" = "https://github.com/bast1waw/BlackStickX-Modpack/releases/download/v1.0.0/SKlauncher-3.2.18_Setup.exe"
}

# -----------------------------------------------------------------
# LOGGING SYSTEM
# -----------------------------------------------------------------
function Write-Log {
    Param (
        [string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS")]
        [string]$Level = "INFO"
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogLine = "[$Timestamp] [$Level] $Message"
    Add-Content -Path $LogPath -Value $LogLine -ErrorAction SilentlyContinue

    switch ($Level) {
        "SUCCESS" { Write-Host $Message -ForegroundColor Green }
        "WARN"    { Write-Host $Message -ForegroundColor Yellow }
        "ERROR"   { Write-Host $Message -ForegroundColor Red }
        Default   { Write-Host $Message -ForegroundColor Cyan }
    }
}

# -----------------------------------------------------------------
# CORE UTILITY FUNCTIONS
# -----------------------------------------------------------------
function Initialize-Environment {
    Write-Log "Initializing workspace environments..." "INFO"
    if (-not (Test-Path $MinecraftDir)) {
        New-Item -ItemType Directory -Path $MinecraftDir | Out-Null
        Write-Log "Created base target path: $MinecraftDir" "INFO"
    }
    if (Test-Path $WorkDir) {
        Remove-Item -Path $WorkDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    New-Item -ItemType Directory -Path $WorkDir | Out-Null
}

function Invoke-SecureDownload {
    Param (
        [string]$Url,
        [string]$DestinationPath,
        [string]$FileName
    )
    Write-Log "Downloading $FileName (High-Speed Mode)..." "INFO"
    
    $WebClient = $null
    
    try {
        $OldProgressPreference = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'

        $WebClient = New-Object System.Net.WebClient
        $WebClient.DownloadFile($Url, $DestinationPath)
        
        $ProgressPreference = $OldProgressPreference
        $WebClient.Dispose()
        
        Write-Log "Successfully downloaded $FileName" "SUCCESS"
    }
    catch {
        if ($WebClient -ne $null) { $WebClient.Dispose() }
        Write-Log "Failed to download $FileName from $Url. Details: $_" "ERROR"
        throw $_
    }
}

function Safe-ExtractArchive {
    Param (
        [string]$ZipPath,
        [string]$ExtractLocation
    )
    Write-Log "Extracting package $(Split-Path $ZipPath -Leaf)..." "INFO"
    try {
        if (-not (Test-Path $ExtractLocation)) {
            New-Item -ItemType Directory -Path $ExtractLocation | Out-Null
        }
        
        if (Get-Command Expand-Archive -ErrorAction SilentlyContinue) {
            Expand-Archive -Path $ZipPath -DestinationPath $ExtractLocation -Force
        } else {
            [System.Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.FileSystem") | Out-Null
            [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipPath, $ExtractLocation)
        }
    }
    catch {
        Write-Log "Extraction routine encountered a critical error: $_" "ERROR"
        throw $_
    }
}

# -----------------------------------------------------------------
# SUBSYSTEM RUNTIMES (JAVA & FORGE VALIDATION)
# -----------------------------------------------------------------
function Get-Java18Binary {
    Write-Log "Scanning system registers and filesystem targets for Java 18..." "INFO"
    
    $RegistryPaths = @(
        "HKLM:\SOFTWARE\JavaSoft\Java Runtime Environment",
        "HKLM:\SOFTWARE\JavaSoft\JDK",
        "HKLM:\SOFTWARE\Eclipse Adoptium\JDK",
        "HKLM:\SOFTWARE\Azul Systems\Zulu",
        "HKCU:\SOFTWARE\JavaSoft\JDK"
    )
    
    foreach ($RegPath in $RegistryPaths) {
        if (Test-Path $RegPath) {
            $Keys = Get-ChildItem -Path $RegPath -ErrorAction SilentlyContinue
            foreach ($Key in $Keys) {
                if ($Key.Name -match "18\.+|jdk-18.+") {
                    $JavaHome = Get-ItemProperty -Path $Key.PSPath -Name "JavaHome" -ErrorAction SilentlyContinue
                    if ($JavaHome) {
                        $PathToCheck = Join-Path $JavaHome.JavaHome "bin\java.exe"
                        if (Test-Path $PathToCheck) {
                            Write-Log "Found Java 18 via Registry: $PathToCheck" "SUCCESS"
                            return $PathToCheck
                        }
                    }
                }
            }
        }
    }

    $StandardPaths = @(
        "$env:ProgramFiles\Java",
        "${env:ProgramFiles(x86)}\Java",
        "$env:ProgramFiles\Eclipse Foundation",
        "$env:ProgramFiles\Zulu"
    )

    foreach ($Folder in $StandardPaths) {
        if (Test-Path $Folder) {
            $Executables = Get-ChildItem -Path $Folder -Filter "java.exe" -Recurse -ErrorAction SilentlyContinue
            foreach ($Exe in $Executables) {
                $VersionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($Exe.FullName)
                if ($VersionInfo.ProductVersion -match "^18\." -or $VersionInfo.FileVersion -match "^18\.") {
                    Write-Log "Found Java 18 via Local Filesystem Scan: $($Exe.FullName)" "SUCCESS"
                    return $Exe.FullName
                }
            }
        }
    }

    if (Get-Command java -ErrorAction SilentlyContinue) {
        $SysVersion = & java -version 2>&1 | Out-String
        if ($SysVersion -match 'version "18\.') {
            $Path = (Get-Command java).Source
            Write-Log "Found Java 18 active on System PATH: $Path" "SUCCESS"
            return $Path
        }
    }

    return $null
}

function Ensure-Java18Environment {
    $JavaPath = Get-Java18Binary
    if ($JavaPath -eq $null) {
        Write-Log "Java 18 runtime could not be detected. Launching automated deployment..." "WARN"
        $LocalJavaExe = Join-Path $WorkDir "jdk18_installer.exe"
        Invoke-SecureDownload -Url $Downloads["Java18"] -DestinationPath $LocalJavaExe -FileName "Java 18 Installer"
        
        Write-Log "Executing Java 18 installer setup silently. Please authorize prompts if requested..." "INFO"
        $Process = Start-Process -FilePath $LocalJavaExe -ArgumentList "/s" -PassThru -Wait
        
        $JavaPath = Get-Java18Binary
        if ($JavaPath -eq $null) {
            Write-Log "Critical error: Java 18 installation finished, but deployment status verification failed." "ERROR"
            throw "Runtime Dependency Resolution Failure: Java 18 Missing."
        }
    }
    return $JavaPath
}

# -----------------------------------------------------------------
# DATA MANAGEMENT PURGE AND OVERWRITE CONTROLLERS
# -----------------------------------------------------------------
function Get-ForgeInstallationStatus {
    $ExpectedJson = Join-Path $VersionsDir "$ForgeTargetID\$ForgeTargetID.json"
    if (Test-Path $ExpectedJson) {
        Write-Log "Forge installation variant identified: $ForgeTargetID" "SUCCESS"
        return $true
    }
    Write-Log "Forge target runtime profile ($ForgeTargetID) was not detected inside targets." "WARN"
    return $false
}

function Ensure-ForgeEnvironment {
    Param([string]$JavaExecutable)
    
    if (-not (Get-ForgeInstallationStatus)) {
        Write-Log "Initializing Forge $ForgeVersion installation workflow..." "INFO"
        $LocalForgeJar = Join-Path $WorkDir "forge_installer.jar"
        Invoke-SecureDownload -Url $Downloads["Forge"] -DestinationPath $LocalForgeJar -FileName "Forge Installer Package"
        
        Write-Log "Running official Forge client binary extraction wrapper..." "INFO"
        $ArgumentList = "-jar `"$LocalForgeJar`" --installClient"
        
        $Process = Start-Process -FilePath $JavaExecutable -ArgumentList $ArgumentList -WorkingDirectory $WorkDir -PassThru -Wait
        
        if (-not (Get-ForgeInstallationStatus)) {
            Write-Log "Forge binary installation failed or client profile was rejected by modpack layout standards." "ERROR"
            throw "Forge Framework Installation Failure."
        }
        Write-Log "Forge system core runtime has been successfully bound to launcher parameters." "SUCCESS"
    }
}

function Clean-ModpackDirectories {
    Write-Log "Executing safe targeted purge operations..." "INFO"
    foreach ($Folder in $ModpackFolders) {
        $TargetPath = Join-Path $MinecraftDir $Folder
        if (Test-Path $TargetPath) {
            try {
                Remove-Item -Path $TargetPath -Recurse -Force
                Write-Log "Purged active directory block: /$Folder" "INFO"
            }
            catch {
                Write-Log "Unable to drop folder structural configuration at $Folder. Ensure Minecraft is not active." "WARN"
            }
        }
    }
    Write-Log "Target clean phase complete. Guarded content properties protected safely." "SUCCESS"
}

# -----------------------------------------------------------------
# COMPONENT ROUTINES (INSTALL / UPDATE / REPAIR / UNINSTALL)
# -----------------------------------------------------------------
function Invoke-FullInstallation {
    Write-Log "=========================================" "INFO"
    Write-Log "STARTING BLACKSTICKX FULL MODPACK INSTALLATION" "INFO"
    Write-Log "=========================================" "INFO"
    
    Initialize-Environment
    $JavaPath = Ensure-Java18Environment
    Ensure-ForgeEnvironment -JavaExecutable $JavaPath
    Clean-ModpackDirectories

    # Package Delivery Execution Pipeline (Dirigido a subcarpetas específicas)
    $Packages = @("Mods", "Config", "Defaultconfigs", "KubeJS", "Resourcepacks", "Shaderpacks")
    foreach ($Pkg in $Packages) {
        $ZipDest = Join-Path $WorkDir "$Pkg.zip"
        Invoke-SecureDownload -Url $Downloads[$Pkg] -DestinationPath $ZipDest -FileName "$Pkg Archive Files"
        
        $TargetFolder = Join-Path $MinecraftDir ($Pkg.ToLower())
        Safe-ExtractArchive -ZipPath $ZipDest -ExtractLocation $TargetFolder
    }

    # Meta Assets Configuration Integration (Archivos sueltos en la raíz)
    $ServerDatPath = Join-Path $MinecraftDir "servers.dat"
    Invoke-SecureDownload -Url $Downloads["ServersDat"] -DestinationPath $ServerDatPath -FileName "Global Multi-Server Profiles"

    $ManifestPath = Join-Path $MinecraftDir "manifest.json"
    Invoke-SecureDownload -Url $Downloads["Manifest"] -DestinationPath $ManifestPath -FileName "Modpack Architecture Manifest"

    Write-Log "Installation workflow execution completed successfully!" "SUCCESS"
}

function Invoke-UpdateWorkflow {
    Write-Log "=========================================" "INFO"
    Write-Log "STARTING BLACKSTICKX STICKY UPDATE (MODS & CONFIG ONLY)" "INFO"
    Write-Log "=========================================" "INFO"
    
    Initialize-Environment
    
    # Purgar quirúrgicamente solo Mods y Config
    foreach ($Folder in $UpdateFolders) {
        $TargetPath = Join-Path $MinecraftDir $Folder
        if (Test-Path $TargetPath) {
            try {
                Remove-Item -Path $TargetPath -Recurse -Force
                Write-Log "Surgical purge complete on target branch: /$Folder" "INFO"
            }
            catch {
                Write-Log "Could not clear /$Folder. Check if Minecraft is running." "WARN"
            }
        }
    }
    
    # Descargar e instalar exclusivamente los paquetes solicitados en sus carpetas dedicadas
    $Packages = @("Mods", "Config")
    foreach ($Pkg in $Packages) {
        $ZipDest = Join-Path $WorkDir "$Pkg.zip"
        Invoke-SecureDownload -Url $Downloads[$Pkg] -DestinationPath $ZipDest -FileName "$Pkg Update Archive"
        
        $TargetFolder = Join-Path $MinecraftDir ($Pkg.ToLower())
        Safe-ExtractArchive -ZipPath $ZipDest -ExtractLocation $TargetFolder
    }

    $ManifestPath = Join-Path $MinecraftDir "manifest.json"
    Invoke-SecureDownload -Url $Downloads["Manifest"] -DestinationPath $ManifestPath -FileName "Updating Manifest References"

    Write-Log "Surgical update workflow for Mods and Config executed correctly." "SUCCESS"
}

function Invoke-RepairWorkflow {
    Write-Log "=========================================" "INFO"
    Write-Log "STARTING BLACKSTICKX STRUCTURAL SYSTEM REPAIR" "INFO"
    Write-Log "=========================================" "INFO"
    
    Initialize-Environment
    $JavaPath = Ensure-Java18Environment
    Ensure-ForgeEnvironment -JavaExecutable $JavaPath

    $Packages = @("Mods", "Config", "Defaultconfigs", "KubeJS", "Resourcepacks", "Shaderpacks")
    foreach ($Pkg in $Packages) {
        $LocalFolderPath = Join-Path $MinecraftDir ($Pkg.ToLower())
        if (-not (Test-Path $LocalFolderPath) -or (Get-ChildItem $LocalFolderPath -ErrorAction SilentlyContinue).Count -eq 0) {
            Write-Log "Missing or degraded directory components verified at: /$Pkg. Correcting structural properties..." "WARN"
            if (Test-Path $LocalFolderPath) { Remove-Item -Path $LocalFolderPath -Recurse -Force | Out-Null }
            
            $ZipDest = Join-Path $WorkDir "$Pkg.zip"
            Invoke-SecureDownload -Url $Downloads[$Pkg] -DestinationPath $ZipDest -FileName "$Pkg Restoration Archive"
            Safe-ExtractArchive -ZipPath $ZipDest -ExtractLocation $LocalFolderPath
        } else {
            Write-Log "Directory integrity validation passed for structural node: /$Pkg" "SUCCESS"
        }
    }

    $ServerDatPath = Join-Path $MinecraftDir "servers.dat"
    if (-not (Test-Path $ServerDatPath)) {
        Invoke-SecureDownload -Url $Downloads["ServersDat"] -DestinationPath $ServerDatPath -FileName "Restoring Server Profiles"
    }

    Write-Log "Repair routine complete. System environment state stable." "SUCCESS"
}

function Invoke-Uninstallation {
    Write-Log "=========================================" "INFO"
    Write-Log "STARTING BLACKSTICKX CLEAN UNINSTALLATION" "INFO"
    Write-Log "=========================================" "INFO"
    
    Clean-ModpackDirectories
    
    $ManifestPath = Join-Path $MinecraftDir "manifest.json"
    if (Test-Path $ManifestPath) { Remove-Item $ManifestPath -Force }
    
    Write-Log "BlackStickX Modpack structural definitions cleanly removed. User profiles and metadata preserved." "SUCCESS"
}

# -----------------------------------------------------------------
# INTERACTIVE TERMINAL USER INTERFACE
# -----------------------------------------------------------------
function Show-MainMenu {
    Clear-Host
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "                 BLACKSTICKX MODPACK INSTALLER                  " -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host " Versión del Modpack: 1.20.1 | Forge: $ForgeVersion" -ForegroundColor Gray
    Write-Host " Destino: $MinecraftDir" -ForegroundColor Gray
    Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host " [1] Instalar (Instalación limpia completa)" -ForegroundColor White
    Write-Host " [2] Actualizar (Solo Mods y Config, mantiene todo lo demás)" -ForegroundColor White
    Write-Host " [3] Reparar (Verifica y descarga componentes faltantes)" -ForegroundColor White
    Write-Host " [4] Desinstalar (Elimina el modpack de forma segura)" -ForegroundColor White
    Write-Host " [5] Abrir Carpeta .minecraft" -ForegroundColor White
    Write-Host " [6] Salir" -ForegroundColor White
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
}

# Main Application Entry Execution Loop
do {
    Show-MainMenu
    $Choice = Read-Host "Seleccione una opción de gestión [1-6]"
    
    try {
        switch ($Choice) {
            "1" {
                Invoke-FullInstallation
                Write-Host "`nOperación completada sin problemas. Presione cualquier tecla para volver al menú principal..." -ForegroundColor Green
                [void]$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            "2" {
                Invoke-UpdateWorkflow
                Write-Host "`nActualización del sistema completada. Presione cualquier tecla para continuar..." -ForegroundColor Green
                [void]$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            "3" {
                Invoke-RepairWorkflow
                Write-Host "`nAnálisis y corrección de datos completado. Presione cualquier tecla para continuar..." -ForegroundColor Green
                [void]$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            "4" {
                Invoke-Uninstallation
                Write-Host "`nModpack desinstalado exitosamente. Presione cualquier tecla para continuar..." -ForegroundColor Green
                [void]$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            "5" {
                Write-Log "Opening Windows Explorer environment at root installation directory target..." "INFO"
                Start-Process explorer.exe -ArgumentList "`"$MinecraftDir`""
            }
            "6" {
                Write-Log "Terminating installer instances safely. Goodbye." "INFO"
                break
            }
            Default {
                Write-Host "Entrada inválida. Por favor elija un número válido del menú de gestión." -ForegroundColor Yellow
                Start-Sleep -Seconds 2
            }
        }
    }
    catch {
        Write-Host "`nSe ha interrumpido el flujo debido a un error crítico durante la ejecución." -ForegroundColor Red
        Write-Host "Consulte el archivo de registro en: $LogPath para ver detalles específicos del error." -ForegroundColor Yellow
        Write-Host "Presione cualquier tecla para regresar al menú..." -ForegroundColor White
        [void]$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
    
} while ($Choice -ne "6")
