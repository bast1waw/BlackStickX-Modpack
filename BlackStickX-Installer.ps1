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
$MinecraftDir         = Join-Path $env:APPDATA ".minecraft"
$OfficialProfilesJson = Join-Path $MinecraftDir "launcher_profiles.json"
$SKLauncherDir        = Join-Path $env:APPDATA "sklauncher"
$SKProfilesJson       = Join-Path $SKLauncherDir "profiles.json"
$VersionsDir          = Join-Path $MinecraftDir "versions"
$ForgeVersion         = "1.20.1-47.4.22"
$ForgeTargetID        = "1.20.1-forge-47.4.22"
$LogPath              = Join-Path $env:TEMP "BlackStickXInstaller.log"
$WorkDir              = Join-Path $env:TEMP "BlackStickX_Setup"

# Core Modpack Directories to Manage
$ModpackFolders = @("mods", "config", "defaultconfigs", "kubejs", "resourcepacks", "shaderpacks")

# Specific Targets for the Strict Update Subsystem (Only Mods & Config)
$UpdateFolders = @("mods", "config")

# Download URLs Manifest
$Downloads = @{
    "Config"         = "https://github.com/bast1waw/BlackStickX-Modpack/releases/download/v1.0.0/config.zip";
    "Defaultconfigs" = "https://github.com/bast1waw/BlackStickX-Modpack/releases/download/v1.0.0/defaultconfigs.zip";
    "Forge"          = "https://github.com/bast1waw/BlackStickX-Modpack/releases/download/v1.0.0/forge-1.20.1-47.4.22-installer.jar";
    "Java18"         = "https://github.com/bast1waw/BlackStickX-Modpack/releases/download/v1.0.0/jdk-18.0.2.1_windows-x64_bin.exe";
    "Java21"         = "https://github.com/bast1waw/BlackStickX-Modpack/releases/download/v1.0.0/jdk-21.0.11_windows-x64_bin.exe";
    "KubeJS"         = "https://github.com/bast1waw/BlackStickX-Modpack/releases/download/v1.0.0/kubejs.zip";
    "Manifest"       = "https://github.com/bast1waw/BlackStickX-Modpack/releases/download/v1.0.0/manifest.json";
    "Mods"           = "https://github.com/bast1waw/BlackStickX-Modpack/releases/download/v1.0.0/mods.zip";
    "Resourcepacks"  = "https://github.com/bast1waw/BlackStickX-Modpack/releases/download/v1.0.0/resourcepacks.zip";
    "ServersDat"     = "https://github.com/bast1waw/BlackStickX-Modpack/releases/download/v1.0.0/servers.dat";
    "Shaderpacks"    = "https://github.com/bast1waw/BlackStickX-Modpack/releases/download/v1.0.0/shaderpacks.zip";
    "SKLauncherJar"  = "https://github.com/bast1waw/BlackStickX-Modpack/releases/download/v1.0.0/SKlauncher-3.2.18.jar";
    "SKLauncherExe"  = "https://github.com/bast1waw/BlackStickX-Modpack/releases/download/v1.0.0/SKlauncher-3.2.18_Setup.exe";
    "ModpackIcon"    = "https://raw.githubusercontent.com/bast1waw/BlackStickX-Modpack/main/BlackStickX%20Logo%20Install%20Launcher.png"
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
# DYNAMIC RAM MANAGEMENT SUBSYSTEM
# -----------------------------------------------------------------
function Get-UserRamChoice {
    Write-Log "Detectando la memoria RAM física del sistema..." "INFO"
    
    $TotalPhysicalMemory = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory
    $TotalRamGB = [Math]::Round($TotalPhysicalMemory / 1GB)
    
    Write-Log "RAM Total Detectada: $TotalRamGB GB" "SUCCESS"

    $MaxSafeRam = [Math]::Floor($TotalRamGB * 0.75)
    if ($MaxSafeRam -lt 4) { $MaxSafeRam = 4 }

    $RecommendedRam = 4
    if ($TotalRamGB -ge 16) {
        $RecommendedRam = 8
    } elseif ($TotalRamGB -ge 12) {
        $RecommendedRam = 6
    }

    Clear-Host
    Write-Host "====================================================================" -ForegroundColor Cyan
    Write-Host "                CONFIGURACIÓN DE MEMORIA RAM (JVM)                  " -ForegroundColor Cyan
    Write-Host "====================================================================" -ForegroundColor Cyan
    Write-Host "  Tu PC cuenta con un total de: $TotalRamGB GB de RAM." -ForegroundColor Gray
    Write-Host "  Selecciona cuánta memoria deseas asignar a BlackStickX:" -ForegroundColor White
    Write-Host "--------------------------------------------------------------------" -ForegroundColor Cyan
    
    $Options = @{}
    $Index = 1

    Write-Host "  [$Index] 4 GB  <-- [MÍNIMO REQUERIDO]" -ForegroundColor Yellow
    $Options.Add($Index.ToString(), 4)
    $Index++

    if ($RecommendedRam -gt 4 -and $RecommendedRam -le $MaxSafeRam) {
        Write-Host "  [$Index] $RecommendedRam GB  <-- [RECOMENDADO PARA TU PC]" -ForegroundColor Green
        $Options.Add($Index.ToString(), $RecommendedRam)
        $Index++
    }

    $PossibleGbs = @(6, 8, 12, 16, 24, 32)
    foreach ($gb in $PossibleGbs) {
        if ($gb -le $MaxSafeRam -and $gb -ne 4 -and $gb -ne $RecommendedRam) {
            Write-Host "  [$Index] $gb GB" -ForegroundColor White
            $Options.Add($Index.ToString(), $gb)
            $Index++
        }
    }
    Write-Host "====================================================================" -ForegroundColor Cyan
    Write-Host ""

    $Selection = ""
    while (-not $Options.ContainsKey($Selection)) {
        $Selection = Read-Host "  Selecciona una opción de asignación [1-$($Index-1)]"
        if (-not $Options.ContainsKey($Selection)) {
            Write-Host "  Opción inválida. Inténtalo de nuevo." -ForegroundColor Red
        }
    }

    $SelectedRam = $Options[$Selection]
    Write-Log "El usuario seleccionó asignar $SelectedRam GB de RAM al cliente." "SUCCESS"
    return $SelectedRam
}

# -----------------------------------------------------------------
# LAUNCHER PROFILE CONFIGURATORS (PREMIUM & NO-PREMIUM)
# -----------------------------------------------------------------
function Configure-OfficialLauncherProfile {
    Param (
        [int]$SelectedRamGB = 4
    )
    Write-Log "Configuring official Minecraft Launcher profile for Premium users..." "INFO"
    
    $LocalLogoPath = Join-Path $WorkDir "modpack_logo.png"
    $IconBase64 = "Furnace" # Respaldo por defecto

    try {
        Invoke-SecureDownload -Url $Downloads["ModpackIcon"] -DestinationPath $LocalLogoPath -FileName "Custom Modpack Logo"
        
        if (Test-Path $LocalLogoPath) {
            $Bytes = [IO.File]::ReadAllBytes($LocalLogoPath)
            $Base64String = [Convert]::ToBase64String($Bytes)
            $IconBase64 = "data:image/png;base64,$Base64String"
            Write-Log "Custom PNG logo successfully encoded into Base64 format." "SUCCESS"
        }
    }
    catch {
        Write-Log "Could not process custom logo. Falling back to default furnace icon." "WARN"
    }
    
    $JvmArgs = "-Xmx${SelectedRamGB}G -XX:+UnlockExperimentalVMOptions -XX:+UseG1GC -XX:G1NewSizePercent=20 -XX:G1ReservePercent=20 -XX:MaxGCPauseMillis=50 -XX:G1HeapRegionSize=32M"
    $ProfileID = "bb546bf4fb01335bc30f527b680f100b"
    $Timestamp = (Get-Date -ToUniversalTime).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")

    $NewProfile = [ordered]@{
        "created"       = $Timestamp
        "icon"          = $IconBase64
        "javaArgs"      = $JvmArgs
        "lastUsed"      = "1970-01-01T00:00:00.000Z"
        "lastVersionId" = $ForgeTargetID
        "name"          = "BlackStickX"
        "type"          = "custom"
    }

    $ProfilesDict = [ordered]@{}
    $FileVersion = 6

    if (Test-Path $OfficialProfilesJson) {
        try {
            $RawText = [System.IO.File]::ReadAllText($OfficialProfilesJson)
            if (-not [string]::IsNullOrWhiteSpace($RawText)) {
                $Parsed = $RawText | ConvertFrom-Json
                if ($null -ne $Parsed.version) { $FileVersion = $Parsed.version }
                
                if ($null -ne $Parsed.profiles) {
                    foreach ($prop in $Parsed.profiles.psobject.Properties) {
                        $ProfilesDict[$prop.Name] = $prop.Value
                    }
                }
            }
        }
        catch {
            Write-Log "Failed to parse launcher_profiles.json. Rebuilding structure." "WARN"
        }
    }

    if ($ProfilesDict.Contains($ProfileID) -and $null -ne $ProfilesDict[$ProfileID].created) {
        $NewProfile["created"] = $ProfilesDict[$ProfileID].created
    }

    $ProfilesDict[$ProfileID] = $NewProfile

    $FinalStructure = [ordered]@{
        "profiles" = $ProfilesDict
        "version"  = $FileVersion
    }

    $Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    $JsonString = ConvertTo-Json $FinalStructure -Depth 30
    [System.IO.File]::WriteAllText($OfficialProfilesJson, $JsonString, $Utf8NoBom)

    Write-Log "Successfully updated 'BlackStickX' profile in Official Launcher." "SUCCESS"
}

function Configure-SKLauncherProfile {
    Param (
        [int]$SelectedRamGB = 4
    )
    Write-Log "Configuring custom SKLauncher profile subsystem..." "INFO"
    
    if (-not (Test-Path $SKLauncherDir)) {
        New-Item -ItemType Directory -Path $SKLauncherDir | Out-Null
    }

    $RamInMB = [int]($SelectedRamGB * 1024)
    $TargetProfileId = "profile-blackstickx-modpack"
    
    $NewProfile = [ordered]@{
        "id"               = $TargetProfileId
        "name"             = "BlackStickX"
        "version"          = $ForgeTargetID
        "maxRam"           = $RamInMB
        "customResolution" = $false
        "resolutionWidth"  = 854
        "resolutionHeight" = 480
        "visibility"       = "CLOSE_LAUNCHER"
    }

    $ProfilesList = [System.Collections.Generic.List[object]]::new()

    if (Test-Path $SKProfilesJson) {
        try {
            $RawText = [System.IO.File]::ReadAllText($SKProfilesJson)
            if (-not [string]::IsNullOrWhiteSpace($RawText)) {
                $ParsedJson = $RawText | ConvertFrom-Json
                if ($null -ne $ParsedJson.profiles) {
                    foreach ($p in $ParsedJson.profiles) {
                        if ($p.id -ne $TargetProfileId) {
                            $ProfilesList.Add($p)
                        }
                    }
                }
            }
        }
        catch {
            Write-Log "Existing SKLauncher profiles.json was unreadable or corrupted." "WARN"
        }
    }

    $ProfilesList.Add($NewProfile)

    $ProfilesStructure = [ordered]@{
        "profiles" = $ProfilesList.ToArray()
    }

    $Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    $JsonOutput = ConvertTo-Json $ProfilesStructure -Depth 10
    [System.IO.File]::WriteAllText($SKProfilesJson, $JsonOutput, $Utf8NoBom)

    Write-Log "Profile 'BlackStickX' synchronized successfully in SKLauncher with ${SelectedRamGB}GB RAM." "SUCCESS"
}

function Remove-LauncherProfiles {
    Write-Log "Removing BlackStickX profile registrations from launchers..." "INFO"
    
    # 1. Official Launcher
    $ProfileID = "bb546bf4fb01335bc30f527b680f100b"
    if (Test-Path $OfficialProfilesJson) {
        try {
            $RawText = [System.IO.File]::ReadAllText($OfficialProfilesJson)
            if (-not [string]::IsNullOrWhiteSpace($RawText)) {
                $Parsed = $RawText | ConvertFrom-Json
                if ($null -ne $Parsed.profiles) {
                    $ProfilesDict = [ordered]@{}
                    foreach ($prop in $Parsed.profiles.psobject.Properties) {
                        if ($prop.Name -ne $ProfileID) {
                            $ProfilesDict[$prop.Name] = $prop.Value
                        }
                    }
                    
                    $FinalStructure = [ordered]@{
                        "profiles" = $ProfilesDict
                        "version"  = if ($null -ne $Parsed.version) { $Parsed.version } else { 6 }
                    }
                    
                    $Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
                    $JsonString = ConvertTo-Json $FinalStructure -Depth 30
                    [System.IO.File]::WriteAllText($OfficialProfilesJson, $JsonString, $Utf8NoBom)
                    Write-Log "Removed BlackStickX profile from Official Launcher." "SUCCESS"
                }
            }
        }
        catch {
            Write-Log "Could not modify launcher_profiles.json during uninstallation." "WARN"
        }
    }

    # 2. SKLauncher
    $TargetProfileId = "profile-blackstickx-modpack"
    if (Test-Path $SKProfilesJson) {
        try {
            $RawText = [System.IO.File]::ReadAllText($SKProfilesJson)
            if (-not [string]::IsNullOrWhiteSpace($RawText)) {
                $ParsedJson = $RawText | ConvertFrom-Json
                if ($null -ne $ParsedJson.profiles) {
                    $ProfilesList = [System.Collections.Generic.List[object]]::new()
                    foreach ($p in $ParsedJson.profiles) {
                        if ($p.id -ne $TargetProfileId) {
                            $ProfilesList.Add($p)
                        }
                    }
                    
                    $ProfilesStructure = [ordered]@{
                        "profiles" = $ProfilesList.ToArray()
                    }
                    
                    $Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
                    $JsonOutput = ConvertTo-Json $ProfilesStructure -Depth 10
                    [System.IO.File]::WriteAllText($SKProfilesJson, $JsonOutput, $Utf8NoBom)
                    Write-Log "Removed BlackStickX profile from SKLauncher." "SUCCESS"
                }
            }
        }
        catch {
            Write-Log "Could not modify SKLauncher profiles.json during uninstallation." "WARN"
        }
    }
}

function Deploy-SKLauncher {
    Write-Log "Downloading official SKLauncher Setup variant..." "INFO"
    $DesktopPath = [Environment]::GetFolderPath("Desktop")
    $LauncherDest = Join-Path $DesktopPath "SKlauncher.exe"
    
    if (-not (Test-Path $LauncherDest)) {
        Invoke-SecureDownload -Url $Downloads["SKLauncherExe"] -DestinationPath $LauncherDest -FileName "SKLauncher Executable"
        Write-Log "SKLauncher executable shortcut deployed cleanly onto User Desktop." "SUCCESS"
    } else {
        Write-Log "SKLauncher binary already available on Desktop. Skipping redownload." "INFO"
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
        
        Write-Log "Executing Java 18 installer setup silently..." "INFO"
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
            Write-Log "Forge binary installation failed." "ERROR"
            throw "Forge Framework Installation Failure."
        }
        Write-Log "Forge system core runtime has been successfully bound." "SUCCESS"
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
                Write-Log "Unable to drop folder structure at $Folder. Ensure Minecraft is not active." "WARN"
            }
        }
    }
    Write-Log "Target clean phase complete." "SUCCESS"
}

# -----------------------------------------------------------------
# COMPONENT ROUTINES (INSTALL / UPDATE / REPAIR / UNINSTALL)
# -----------------------------------------------------------------
function Invoke-FullInstallation {
    Write-Log "=========================================" "INFO"
    Write-Log "STARTING BLACKSTICKX FULL MODPACK INSTALLATION" "INFO"
    Write-Log "=========================================" "INFO"
    
    $ChosenRam = Get-UserRamChoice
    
    Initialize-Environment
    $JavaPath = Ensure-Java18Environment
    Ensure-ForgeEnvironment -JavaExecutable $JavaPath
    Clean-ModpackDirectories

    $Packages = @("Mods", "Config", "Defaultconfigs", "KubeJS", "Resourcepacks", "Shaderpacks")
    foreach ($Pkg in $Packages) {
        $ZipDest = Join-Path $WorkDir "$Pkg.zip"
        Invoke-SecureDownload -Url $Downloads[$Pkg] -DestinationPath $ZipDest -FileName "$Pkg Archive Files"
        
        $TargetFolder = Join-Path $MinecraftDir ($Pkg.ToLower())
        Safe-ExtractArchive -ZipPath $ZipDest -ExtractLocation $TargetFolder
    }

    $ServerDatPath = Join-Path $MinecraftDir "servers.dat"
    Invoke-SecureDownload -Url $Downloads["ServersDat"] -DestinationPath $ServerDatPath -FileName "Global Multi-Server Profiles"

    $ManifestPath = Join-Path $MinecraftDir "manifest.json"
    Invoke-SecureDownload -Url $Downloads["Manifest"] -DestinationPath $ManifestPath -FileName "Modpack Architecture Manifest"

    Configure-OfficialLauncherProfile -SelectedRamGB $ChosenRam
    Configure-SKLauncherProfile -SelectedRamGB $ChosenRam
    Deploy-SKLauncher

    Write-Log "Installation workflow execution completed successfully!" "SUCCESS"
}

function Invoke-UpdateWorkflow {
    Write-Log "=========================================" "INFO"
    Write-Log "STARTING BLACKSTICKX STICKY UPDATE (MODS & CONFIG ONLY)" "INFO"
    Write-Log "=========================================" "INFO"
    
    $ChosenRam = Get-UserRamChoice
    
    Initialize-Environment
    
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
    
    $Packages = @("Mods", "Config")
    foreach ($Pkg in $Packages) {
        $ZipDest = Join-Path $WorkDir "$Pkg.zip"
        Invoke-SecureDownload -Url $Downloads[$Pkg] -DestinationPath $ZipDest -FileName "$Pkg Update Archive"
        
        $TargetFolder = Join-Path $MinecraftDir ($Pkg.ToLower())
        Safe-ExtractArchive -ZipPath $ZipDest -ExtractLocation $TargetFolder
    }

    $ManifestPath = Join-Path $MinecraftDir "manifest.json"
    Invoke-SecureDownload -Url $Downloads["Manifest"] -DestinationPath $ManifestPath -FileName "Updating Manifest References"
    
    Configure-OfficialLauncherProfile -SelectedRamGB $ChosenRam
    Configure-SKLauncherProfile -SelectedRamGB $ChosenRam

    Write-Log "Surgical update workflow for Mods and Config executed correctly." "SUCCESS"
}

function Invoke-RepairWorkflow {
    Write-Log "=========================================" "INFO"
    Write-Log "STARTING BLACKSTICKX COMPLETE RE-INSTALLATION REPAIR" "INFO"
    Write-Log "=========================================" "INFO"
    
    Write-Log "Step 1: Purging all existing modpack folders and definitions..." "WARN"
    Invoke-Uninstallation
    
    Write-Log "Step 2: Launching fresh software stack deployment..." "INFO"
    Invoke-FullInstallation

    Write-Log "Deep structural repair completed. All assets wiped and cleanly re-downloaded." "SUCCESS"
}

function Invoke-Uninstallation {
    Write-Log "=========================================" "INFO"
    Write-Log "STARTING BLACKSTICKX CLEAN UNINSTALLATION" "INFO"
    Write-Log "=========================================" "INFO"
    
    Clean-ModpackDirectories
    Remove-LauncherProfiles
    
    $ManifestPath = Join-Path $MinecraftDir "manifest.json"
    if (Test-Path $ManifestPath) { Remove-Item $ManifestPath -Force }
    
    Write-Log "BlackStickX Modpack structural definitions cleanly removed." "SUCCESS"
}

# -----------------------------------------------------------------
# INTERACTIVE TERMINAL USER INTERFACE
# -----------------------------------------------------------------
function Show-MainMenu {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    
    $Host.UI.RawUI.WindowSize = New-Object System.Management.Automation.Host.Size(85, 28)
    $Host.UI.RawUI.BufferSize = New-Object System.Management.Automation.Host.Size(85, 100)
    
    Clear-Host
    Write-Host "`n====================================================================" -ForegroundColor Cyan
    Write-Host "                   BLACKSTICKX MODPACK INSTALLER                    " -ForegroundColor Cyan
    Write-Host "====================================================================" -ForegroundColor Cyan
    Write-Host "  Versión del Modpack: 1.20.1 | Forge: $ForgeVersion" -ForegroundColor Gray
    Write-Host "  Destino: $MinecraftDir" -ForegroundColor Gray
    Write-Host "--------------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host "  [1] Instalar (Instalación limpia completa + Auto Perfiles)" -ForegroundColor White
    Write-Host ""
    Write-Host "  [2] Actualizar (Solo Mods y Config, mantiene todo lo demás)" -ForegroundColor White
    Write-Host ""
    Write-Host "  [3] Reparar (Borrado total y reinstalación limpia completa)" -ForegroundColor White
    Write-Host ""
    Write-Host "  [4] Desinstalar (Elimina el modpack de forma segura)" -ForegroundColor White
    Write-Host ""
    Write-Host "  [5] Abrir Carpeta .minecraft" -ForegroundColor White
    Write-Host ""
    Write-Host "  [6] Salir" -ForegroundColor White
    Write-Host "====================================================================" -ForegroundColor Cyan
    Write-Host ""
}

# Main Application Entry Execution Loop
do {
    Show-MainMenu
    $Choice = Read-Host "  Seleccione una opción de gestión [1-6]"
    
    try {
        switch ($Choice) {
            "1" {
                Invoke-FullInstallation
                Write-Host "`n¡Instalación lista!" -ForegroundColor Green
                Write-Host "El perfil 'BlackStickX' ha sido configurado con tu selección de RAM y tu icono personalizado." -ForegroundColor Green
                Write-Host "Presione cualquier tecla para volver al menú principal..." -ForegroundColor White
                [void]$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            "2" {
                Invoke-UpdateWorkflow
                Write-Host "`n¡Actualización del sistema completada! Presione cualquier tecla para continuar..." -ForegroundColor Green
                [void]$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            "3" {
                Invoke-RepairWorkflow
                Write-Host "`n¡Reparación profunda finalizada con éxito!" -ForegroundColor Green
                Write-Host "Presione cualquier tecla para continuar..." -ForegroundColor White
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
