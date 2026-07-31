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

# Download URLs Manifest (Icono removido de aquí porque ahora es Base64 nativo)
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
    "SKLauncherExe"  = "https://github.com/bast1waw/BlackStickX-Modpack/releases/download/v1.0.0/SKlauncher-3.2.18_Setup.exe"
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
    
    $TargetForgeVersion = if ($script:ForgeTargetID) { $script:ForgeTargetID } else { "1.20.1-forge-47.4.22" }
    $ProfilesJsonPath   = if ($script:OfficialProfilesJson) { $script:OfficialProfilesJson } else { Join-Path $env:APPDATA ".minecraft\launcher_profiles.json" }

    # Logo 128x128 incrustado directamente en Base64
    $IconBase64 = "data:image/png;base64,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"
    
    $JvmArgs = "-Xmx${SelectedRamGB}G -XX:+UnlockExperimentalVMOptions -XX:+UseG1GC -XX:G1NewSizePercent=20 -XX:G1ReservePercent=20 -XX:MaxGCPauseMillis=50 -XX:G1HeapRegionSize=32M"
    $ProfileID = "bb546bf4fb01335bc30f527b680f100b"
    $Timestamp = (Get-Date -ToUniversalTime).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")

    $NewProfile = [ordered]@{
        "created"       = $Timestamp
        "icon"          = $IconBase64
        "javaArgs"      = $JvmArgs
        "lastUsed"      = "1970-01-01T00:00:00.000Z"
        "lastVersionId" = $TargetForgeVersion
        "name"          = "BlackStickX"
        "type"          = "custom"
    }

    $JsonObject = $null
    if (Test-Path $ProfilesJsonPath) {
        try {
            $RawText = [System.IO.File]::ReadAllText($ProfilesJsonPath)
            if (-not [string]::IsNullOrWhiteSpace($RawText)) {
                $JsonObject = $RawText | ConvertFrom-Json
            }
        }
        catch {
            Write-Log "Could not parse existing launcher_profiles.json, creating clean structure." "WARN"
        }
    }

    if ($null -eq $JsonObject) {
        $JsonObject = [PSCustomObject]@{
            profiles = [PSCustomObject]@{}
            settings = [PSCustomObject]@{
                crashAssistance  = $false
                enableAdvanced   = $false
                enableAnalytics  = $true
                enableHistorical = $false
                enableReleases   = $true
                enableSnapshots  = $false
                keepLauncherOpen = $true
                profileSorting   = "ByLastPlayed"
                showGameLog      = $false
                showMenu         = $false
                soundOn          = $false
            }
            version  = 6
        }
    }

    if ($null -eq $JsonObject.profiles) {
        $JsonObject | Add-Member -MemberType NoteProperty -Name "profiles" -Value ([PSCustomObject]@{})
    }

    if ($JsonObject.profiles.psobject.Properties[$ProfileID] -and $JsonObject.profiles.$ProfileID.created) {
        $NewProfile["created"] = $JsonObject.profiles.$ProfileID.created
    }

    if ($JsonObject.profiles.psobject.Properties[$ProfileID]) {
        $JsonObject.profiles.$ProfileID = [PSCustomObject]$NewProfile
    } else {
        $JsonObject.profiles | Add-Member -MemberType NoteProperty -Name $ProfileID -Value ([PSCustomObject]$NewProfile)
    }

    try {
        $Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        $JsonString = ConvertTo-Json $JsonObject -Depth 10
        
        $ParentDir = Split-Path $ProfilesJsonPath -Parent
        if (-not (Test-Path $ParentDir)) { New-Item -ItemType Directory -Path $ParentDir | Out-Null }

        [System.IO.File]::WriteAllText($ProfilesJsonPath, $JsonString, $Utf8NoBom)
        Write-Log "Successfully updated 'BlackStickX' profile in Official Launcher." "SUCCESS"
    }
    catch {
        Write-Log "Error writing launcher_profiles.json: $_" "ERROR"
        throw $_
    }
}

function Configure-SKLauncherProfile {
    Param (
        [int]$SelectedRamGB = 4
    )
    Write-Log "Configuring custom SKLauncher profile subsystem..." "INFO"
    
    $TargetForgeVersion = if ($script:ForgeTargetID) { $script:ForgeTargetID } else { "1.20.1-forge-47.4.22" }
    $SKDir              = if ($script:SKLauncherDir) { $script:SKLauncherDir } else { Join-Path $env:APPDATA "sklauncher" }
    $SKJsonPath         = if ($script:SKProfilesJson) { $script:SKProfilesJson } else { Join-Path $SKDir "profiles.json" }

    if (-not (Test-Path $SKDir)) {
        New-Item -ItemType Directory -Path $SKDir | Out-Null
    }

    $RamInMB = [int]($SelectedRamGB * 1024)
    $TargetProfileId = "profile-blackstickx-modpack"
    
    $NewProfile = [ordered]@{
        "id"               = $TargetProfileId
        "name"             = "BlackStickX"
        "version"          = $TargetForgeVersion
        "maxRam"           = $RamInMB
        "customResolution" = $false
        "resolutionWidth"  = 854
        "resolutionHeight" = 480
        "visibility"       = "CLOSE_LAUNCHER"
    }

    $ProfilesList = [System.Collections.Generic.List[object]]::new()

    if (Test-Path $SKJsonPath) {
        try {
            $RawText = [System.IO.File]::ReadAllText($SKJsonPath)
            if (-not [string]::IsNullOrWhiteSpace($RawText)) {
                $ParsedJson = $RawText | ConvertFrom-Json
                if ($null -ne $ParsedJson -and $null -ne $ParsedJson.profiles) {
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
    [System.IO.File]::WriteAllText($SKJsonPath, $JsonOutput, $Utf8NoBom)

    Write-Log "Profile 'BlackStickX' synchronized successfully in SKLauncher with ${SelectedRamGB}GB RAM." "SUCCESS"
}

function Remove-LauncherProfiles {
    Write-Log "Removing BlackStickX profile registrations from launchers..." "INFO"
    
    $ProfileID = "bb546bf4fb01335bc30f527b680f100b"
    if (Test-Path $OfficialProfilesJson) {
        try {
            $RawText = [System.IO.File]::ReadAllText($OfficialProfilesJson)
            if (-not [string]::IsNullOrWhiteSpace($RawText)) {
                $Parsed = $RawText | ConvertFrom-Json
                if ($null -ne $Parsed -and $null -ne $Parsed.profiles) {
                    $ProfilesDict = [ordered]@{}
                    $Props = Get-Member -InputObject $Parsed.profiles -MemberType NoteProperty
                    foreach ($prop in $Props) {
                        if ($prop.Name -ne $ProfileID) {
                            $pName = $prop.Name
                            $ProfilesDict[$pName] = $Parsed.profiles.$pName
                        }
                    }
                    
                    $Parsed.profiles = $ProfilesDict
                    $Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
                    $JsonString = ConvertTo-Json $Parsed -Depth 30
                    [System.IO.File]::WriteAllText($OfficialProfilesJson, $JsonString, $Utf8NoBom)
                    Write-Log "Removed BlackStickX profile from Official Launcher." "SUCCESS"
                }
            }
        }
        catch {
            Write-Log "Could not modify launcher_profiles.json during uninstallation." "WARN"
        }
    }

    $TargetProfileId = "profile-blackstickx-modpack"
    if (Test-Path $SKProfilesJson) {
        try {
            $RawText = [System.IO.File]::ReadAllText($SKProfilesJson)
            if (-not [string]::IsNullOrWhiteSpace($RawText)) {
                $ParsedJson = $RawText | ConvertFrom-Json
                if ($null -ne $ParsedJson -and $null -ne $ParsedJson.profiles) {
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
                Write-Host "El perfil 'BlackStickX' ha sido configurado con tu selección de RAM y tu icono personalizado de 128x128." -ForegroundColor Green
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
