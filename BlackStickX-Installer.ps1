# =================================================================
# HERRAMIENTA DE INSTALACIÓN Y GESTIÓN AUTOMÁTICA - BLACKSTICKX MODPACK
# Entorno Objetivo: Windows 10 / Windows 11
# Shell Soportado: PowerShell 5.0+
# =================================================================

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Prevenir errores de codificación en la consola (Caracteres extraños)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# -----------------------------------------------------------------
# RUTAS GLOBALES Y CONFIGURACIÓN
# -----------------------------------------------------------------
$MinecraftDir         = Join-Path $env:APPDATA ".minecraft"
$OfficialProfilesJson = Join-Path $MinecraftDir "launcher_profiles.json"
$SKLauncherDir        = Join-Path $env:APPDATA "sklauncher"
$SKLauncherJarPath    = Join-Path $SKLauncherDir "SKlauncher.jar"
$SKProfilesJson       = Join-Path $SKLauncherDir "profiles.json"
$VersionsDir          = Join-Path $MinecraftDir "versions"
$ForgeVersion         = "1.20.1-47.4.22"
$ForgeTargetID        = "1.20.1-forge-47.4.22"
$LogPath              = Join-Path $env:TEMP "BlackStickXInstaller.log"
$WorkDir              = Join-Path $env:TEMP "BlackStickX_Setup"

# Icono del Perfil en Base64 Corregido
$IconBase64 = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAIAAAACACAYAAADDPmHLAAAMnUlEQVR4nO2dC1QVxxnH/xcBSQRqFCMQVEDSJqk2SKFiGqOoaVNraxKssagnJCcnsac1SdPq0WhOW09jajRRT2xz0oj4rG+tMa1RtDWW1hqi+AYfhYgiKCi+BbyX6RnugPexO7vAvXt378zvnPFxd3Z39vu+ncc3M99CIpFIJBKJRCKRSCQiYQuSZ30CwA8BpALoBoCw5EkogOsASgGUA/gKQCWAowCuBPYRJO3hUQB/c1F4e9NlALSvH4A6oE8AkO4+ACD8/23D3wQ46K3eAcB6APUANB3rWwMAgP9nAMgAK9d+B4D07+N5AADlXJ8HAHBeNwCgAODP43vP6H4A9n77/gBAt4b/A/CBAAD091V73hYAAIAbwP8A4P3+AgAAwP8PAIAwBwEAAMjH34c/3gDAh7W/BQAARAB4ACrLq0oWAAAAAElFTkSuQmCC"

# Directorios principales del modpack para gestionar
$ModpackFolders = @("mods", "config", "defaultconfigs", "kubejs", "resourcepacks", "shaderpacks")

# Objetivos específicos para el subsistema de actualización (Solo Mods y Config)
$UpdateFolders = @("mods", "config")

# Manifiesto de URLs de descarga
$Downloads = @{
    "Config"         = "https://github.com/bast1waw/BlackStickX-Modpack/releases/download/v1.0.0/config.zip";
    "Defaultconfigs" = "https://github.com/bast1waw/BlackStickX-Modpack/releases/download/v1.0.0/defaultconfigs.zip";
    "Forge"          = "https://maven.minecraftforge.net/net/minecraftforge/forge/1.20.1-47.4.22/forge-1.20.1-47.4.22-installer.jar";
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
# SISTEMA DE REGISTRO (LOGS)
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
# FUNCIONES PRINCIPALES DE UTILIDAD Y DETECCIÓN EXACTA
# -----------------------------------------------------------------
function Initialize-Environment {
    Write-Log "Inicializando directorios de trabajo..." "INFO"
    if (-not (Test-Path $MinecraftDir)) {
        New-Item -ItemType Directory -Path $MinecraftDir | Out-Null
        Write-Log "Directorio base creado: $MinecraftDir" "INFO"
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
    Write-Log "Descargando $FileName..." "INFO"
    
    $WebClient = $null
    try {
        $OldProgressPreference = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'

        $WebClient = New-Object System.Net.WebClient
        $WebClient.DownloadFile($Url, $DestinationPath)
        
        $ProgressPreference = $OldProgressPreference
        $WebClient.Dispose()
        
        Write-Log "Descarga completada: $FileName" "SUCCESS"
    }
    catch {
        if ($WebClient -ne $null) { $WebClient.Dispose() }
        Write-Log "Error al descargar $FileName desde $Url. Detalles: $_" "ERROR"
        throw $_
    }
}

function Safe-ExtractArchive {
    Param (
        [string]$ZipPath,
        [string]$ExtractLocation,
        [switch]$IsShaderpack
    )
    Write-Log "Extrayendo paquete $(Split-Path $ZipPath -Leaf)..." "INFO"
    try {
        if (-not (Test-Path $ExtractLocation)) {
            New-Item -ItemType Directory -Path $ExtractLocation | Out-Null
        }
        
        if ($IsShaderpack) {
            $TempExtractDir = Join-Path $WorkDir "temp_shaders_extract"
            if (Test-Path $TempExtractDir) { Remove-Item $TempExtractDir -Recurse -Force }
            New-Item -ItemType Directory -Path $TempExtractDir | Out-Null

            if (Get-Command Expand-Archive -ErrorAction SilentlyContinue) {
                Expand-Archive -Path $ZipPath -DestinationPath $TempExtractDir -Force
            } else {
                [System.Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.FileSystem") | Out-Null
                [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipPath, $TempExtractDir)
            }

            $SubItems = Get-ChildItem -Path $TempExtractDir
            if ($SubItems.Count -eq 1 -and $SubItems[0].PSIsContainer) {
                $InnerDir = $SubItems[0].FullName
                Get-ChildItem -Path $InnerDir | Move-Item -Destination $ExtractLocation -Force
            } else {
                Get-ChildItem -Path $TempExtractDir | Move-Item -Destination $ExtractLocation -Force
            }
            Remove-Item -Path $TempExtractDir -Recurse -Force -ErrorAction SilentlyContinue
        } 
        else {
            if (Get-Command Expand-Archive -ErrorAction SilentlyContinue) {
                Expand-Archive -Path $ZipPath -DestinationPath $ExtractLocation -Force
            } else {
                [System.Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.FileSystem") | Out-Null
                [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipPath, $ExtractLocation)
            }
        }
    }
    catch {
        Write-Log "Error durante la extracción del paquete: $_" "ERROR"
        throw $_
    }
}

function Check-InitialLauncherSetup {
    Clear-Host
    Write-Host "====================================================================" -ForegroundColor Cyan
    Write-Host "                  VERIFICACIÓN INICIAL DE CUENTA                    " -ForegroundColor Cyan
    Write-Host "====================================================================" -ForegroundColor Cyan
    Write-Host "  ¿Tienes el Minecraft original?                                    " -ForegroundColor White
    Write-Host "--------------------------------------------------------------------" -ForegroundColor Cyan
    
    $Response = ""
    while ($Response -ne "si" -and $Response -ne "s" -and $Response -ne "no" -and $Response -ne "n") {
        $Response = (Read-Host "  Responde [si / no]").Trim().ToLower()
    }

    if ($Response -eq "si" -or $Response -eq "s") {
        Write-Log "El usuario indicó que tiene Minecraft original. Buscando ejecutable..." "INFO"
        
        $PossibleOfficialPaths = @(
            "$env:LOCALAPPDATA\Microsoft\WindowsApps\MinecraftLauncher.exe",
            "$env:ProgramFiles\Minecraft Launcher\MinecraftLauncher.exe",
            "${env:ProgramFiles(x86)}\Minecraft Launcher\MinecraftLauncher.exe",
            "$env:APPDATA\.minecraft\MinecraftLauncher.exe"
        )

        $FoundOfficial = $false
        foreach ($path in $PossibleOfficialPaths) {
            if (Test-Path $path) {
                Write-Host "  Minecraft Original Detectado en: $path" -ForegroundColor Green
                Write-Log "Minecraft Original Detectado en: $path" "SUCCESS"
                $FoundOfficial = $true
                break
            }
        }

        if (-not $FoundOfficial) {
            try {
                $uwpCheck = Get-AppxPackage -Name *Microsoft.MinecraftUWP* -ErrorAction SilentlyContinue
                if ($uwpCheck) {
                    Write-Host "  Minecraft Original Detectado (Paquete UWP/Windows Store)." -ForegroundColor Green
                    Write-Log "Minecraft Original Detectado vía UWP." "SUCCESS"
                    $FoundOfficial = $true
                }
            } catch {}
        }
    } 
    else {
        Write-Log "El usuario indicó que NO tiene Minecraft original. Verificando SKLauncher..." "INFO"
        
        if (Test-Path $SKLauncherJarPath) {
            Write-Host "  SKLauncher detectado en: $SKLauncherJarPath" -ForegroundColor Green
            Write-Log "SKLauncher detectado en: $SKLauncherJarPath" "SUCCESS"
        } else {
            Write-Host "  SKLauncher no encontrado. Procediendo a instalarlo..." -ForegroundColor Yellow
            Deploy-SKLauncherAndWait
        }
    }

    Write-Host "`n  Verificación completada. Abriendo el instalador..." -ForegroundColor Cyan
    Start-Sleep -Seconds 2
}

function Deploy-SKLauncherAndWait {
    Write-Log "Descargando instalador de SKLauncher..." "INFO"
    $InstallerDest = Join-Path $WorkDir "SKlauncher_Setup.exe"
    
    try {
        Invoke-SecureDownload -Url $Downloads["SKLauncherExe"] -DestinationPath $InstallerDest -FileName "Instalador de SKLauncher"
        Start-Process -FilePath $InstallerDest -Wait

        $TimeoutSeconds = 600
        $Elapsed = 0

        while ($Elapsed -lt $TimeoutSeconds) {
            if (Test-Path $SKLauncherJarPath) {
                Write-Host "  ¡SKLauncher detectado con éxito!" -ForegroundColor Green
                return
            }
            Start-Sleep -Seconds 4
            $Elapsed += 4
        }
    }
    catch {
        Write-Log "Error al gestionar la instalación de SKLauncher: $_" "ERROR"
    }
}

function Get-UserRamChoice {
    $TotalPhysicalMemory = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory
    $TotalRamGB = [Math]::Round($TotalPhysicalMemory / 1GB)
    $MaxSafeRam = [Math]::Floor($TotalRamGB * 0.75)
    if ($MaxSafeRam -lt 4) { $MaxSafeRam = 4 }

    $RecommendedRam = 4
    if ($TotalRamGB -ge 16) { $RecommendedRam = 8 }
    elseif ($TotalRamGB -ge 12) { $RecommendedRam = 6 }

    Clear-Host
    Write-Host "====================================================================" -ForegroundColor Cyan
    Write-Host "                CONFIGURACIÓN DE MEMORIA RAM (JVM)                  " -ForegroundColor Cyan
    Write-Host "====================================================================" -ForegroundColor Cyan
    Write-Host "  Tu PC cuenta con un total de: $TotalRamGB GB de RAM." -ForegroundColor Gray
    Write-Host "  Selecciona cuánta memoria deseas asignar a BlackStickX:" -ForegroundColor White
    Write-Host "--------------------------------------------------------------------" -ForegroundColor Cyan
    
    $Options = @{}
    $Index = 1

    Write-Host "  [$Index] 4 GB  <-- [MINIMO REQUERIDO]" -ForegroundColor Yellow
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
    }

    return $Options[$Selection]
}

function Configure-OfficialLauncherProfile {
    Param (
        [int]$SelectedRamGB = 8
    )
    Write-Log "Configurando el perfil 'blackstickx' con icono personalizado..." "INFO"
    
    $TargetForgeVersion = if ($script:ForgeTargetID) { $script:ForgeTargetID } else { "1.20.1-forge-47.4.22" }
    $ProfilesJsonPath   = if ($script:OfficialProfilesJson) { $script:OfficialProfilesJson } else { Join-Path $env:APPDATA ".minecraft\launcher_profiles.json" }

    $JvmArgs   = "-Xmx${SelectedRamGB}G -XX:+UnlockExperimentalVMOptions -XX:+UseG1GC -XX:G1NewSizePercent=20 -XX:G1ReservePercent=20 -XX:MaxGCPauseMillis=50 -XX:G1HeapRegionSize=32M"
    $ProfileID = "blackstickx"

    $NewProfile = [ordered]@{
        "created"       = "2026-07-31T19:41:10.635Z"
        "icon"          = $script:IconBase64
        "javaArgs"      = $JvmArgs
        "lastUsed"      = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ")
        "lastVersionId" = $TargetForgeVersion
        "name"          = "BlackStickX Server"
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
        catch {}
    }

    if ($null -eq $JsonObject) {
        $JsonObject = [PSCustomObject]@{
            profiles = [PSCustomObject]@{}
            settings = [PSCustomObject]@{ keepLauncherOpen = $true }
            version  = 6
        }
    }

    $JsonObject | Select-Object -Property * | Add-Member -MemberType NoteProperty -Name "selectedProfile" -Value $ProfileID -Force

    if ($null -eq $JsonObject.profiles) {
        $JsonObject | Add-Member -MemberType NoteProperty -Name "profiles" -Value ([PSCustomObject]@{})
    }

    $ProfilesDict = [ordered]@{}
    $ProfilesDict[$ProfileID] = [PSCustomObject]$NewProfile

    $Props = Get-Member -InputObject $JsonObject.profiles -MemberType NoteProperty
    foreach ($prop in $Props) {
        $pName = $prop.Name
        if ($pName -ne $ProfileID) {
            $pData = $JsonObject.profiles.$pName
            if ($pData.lastVersionId -ne $TargetForgeVersion) {
                $ProfilesDict[$pName] = $pData
            }
        }
    }

    $JsonObject.profiles = $ProfilesDict

    try {
        $Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        $JsonString = ConvertTo-Json $JsonObject -Depth 10
        
        $ParentDir = Split-Path $ProfilesJsonPath -Parent
        if (-not (Test-Path $ParentDir)) { New-Item -ItemType Directory -Path $ParentDir | Out-Null }

        [System.IO.File]::WriteAllText($ProfilesJsonPath, $JsonString, $Utf8NoBom)
        Write-Log "Perfil 'blackstickx' actualizado con icono y configurado." "SUCCESS"
    }
    catch {
        Write-Log "Error al escribir en launcher_profiles.json: $_" "ERROR"
        throw $_
    }
}

function Configure-SKLauncherProfile {
    Param (
        [int]$SelectedRamGB = 4
    )
    $SKDir = Join-Path $env:APPDATA "sklauncher"
    $SKJsonPath = Join-Path $SKDir "profiles.json"

    if (-not (Test-Path $SKDir)) { New-Item -ItemType Directory -Path $SKDir | Out-Null }

    $RamInMB = [int]($SelectedRamGB * 1024)
    $TargetProfileId = "profile-blackstickx-modpack"
    
    $NewProfile = [ordered]@{
        "id"               = $TargetProfileId
        "name"             = "BlackStickX Server"
        "version"          = $ForgeTargetID
        "maxRam"           = $RamInMB
        "customResolution" = $false
        "resolutionWidth"  = 854
        "resolutionHeight" = 480
        "visibility"       = "CLOSE_LAUNCHER"
    }

    $ProfilesList = [System.Collections.Generic.List[object]]::new()
    $ProfilesList.Add($NewProfile)

    if (Test-Path $SKJsonPath) {
        try {
            $RawText = [System.IO.File]::ReadAllText($SKJsonPath)
            if (-not [string]::IsNullOrWhiteSpace($RawText)) {
                $ParsedJson = $RawText | ConvertFrom-Json
                if ($null -ne $ParsedJson.profiles) {
                    foreach ($p in $ParsedJson.profiles) {
                        if ($p.id -ne $TargetProfileId) { $ProfilesList.Add($p) }
                    }
                }
            }
        }
        catch {}
    }

    $ProfilesStructure = [ordered]@{ "profiles" = $ProfilesList.ToArray() }
    $Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($SKJsonPath, (ConvertTo-Json $ProfilesStructure -Depth 10), $Utf8NoBom)
}

function Remove-LauncherProfiles {
    if (Test-Path $OfficialProfilesJson) {
        try {
            $RawText = [System.IO.File]::ReadAllText($OfficialProfilesJson)
            if (-not [string]::IsNullOrWhiteSpace($RawText)) {
                $Parsed = $RawText | ConvertFrom-Json
                $ProfilesDict = [ordered]@{}
                foreach ($prop in (Get-Member -InputObject $Parsed.profiles -MemberType NoteProperty)) {
                    if ($prop.Name -ne "blackstickx") { $ProfilesDict[$prop.Name] = $Parsed.profiles.($prop.Name) }
                }
                $Parsed.profiles = $ProfilesDict
                [System.IO.File]::WriteAllText($OfficialProfilesJson, (ConvertTo-Json $Parsed -Depth 30), (New-Object System.Text.UTF8Encoding($false)))
            }
        }
        catch {}
    }
}

function Get-Java18Binary {
    $StandardPaths = @("$env:ProgramFiles\Java", "${env:ProgramFiles(x86)}\Java", "$env:ProgramFiles\Eclipse Foundation")
    foreach ($Folder in $StandardPaths) {
        if (Test-Path $Folder) {
            foreach ($Exe in (Get-ChildItem -Path $Folder -Filter "java.exe" -Recurse -ErrorAction SilentlyContinue)) {
                if ([System.Diagnostics.FileVersionInfo]::GetVersionInfo($Exe.FullName).ProductVersion -match "^18\.") {
                    return $Exe.FullName
                }
            }
        }
    }
    if (Get-Command java -ErrorAction SilentlyContinue) {
        if ((& java -version 2>&1 | Out-String) -match 'version "18\.') { return (Get-Command java).Source }
    }
    return $null
}

function Ensure-Java18Environment {
    $JavaPath = Get-Java18Binary
    if ($null -eq $JavaPath) {
        $LocalJavaExe = Join-Path $WorkDir "jdk18_installer.exe"
        Invoke-SecureDownload -Url $Downloads["Java18"] -DestinationPath $LocalJavaExe -FileName "Java 18"
        Start-Process -FilePath $LocalJavaExe -ArgumentList "/s" -Wait
        $JavaPath = Get-Java18Binary
    }
    return $JavaPath
}

function Get-ForgeInstallationStatus {
    return (Test-Path (Join-Path $VersionsDir "$ForgeTargetID\$ForgeTargetID.json"))
}

function Ensure-ForgeEnvironment {
    Param([string]$JavaExecutable)
    if (Test-Path (Join-Path $VersionsDir $ForgeTargetID)) {
        Remove-Item -Path (Join-Path $VersionsDir $ForgeTargetID) -Recurse -Force -ErrorAction SilentlyContinue
    }
    $LocalForgeJar = Join-Path $WorkDir "forge_installer.jar"
    Invoke-SecureDownload -Url $Downloads["Forge"] -DestinationPath $LocalForgeJar -FileName "Forge"
    Start-Process -FilePath $JavaExecutable -ArgumentList "-jar `"$LocalForgeJar`" --installClient `"$MinecraftDir`"" -WorkingDirectory $WorkDir -Wait -NoNewWindow
}

function Clean-ModpackDirectories {
    foreach ($Folder in $ModpackFolders) {
        $TargetPath = Join-Path $MinecraftDir $Folder
        if (Test-Path $TargetPath) { Remove-Item -Path $TargetPath -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

function Invoke-FullInstallation {
    $ChosenRam = Get-UserRamChoice
    Initialize-Environment
    $JavaPath = Ensure-Java18Environment
    Ensure-ForgeEnvironment -JavaExecutable $JavaPath
    Clean-ModpackDirectories

    foreach ($Pkg in @("Mods", "Config", "Defaultconfigs", "KubeJS", "Resourcepacks", "Shaderpacks")) {
        $ZipDest = Join-Path $WorkDir "$Pkg.zip"
        Invoke-SecureDownload -Url $Downloads[$Pkg] -DestinationPath $ZipDest -FileName $Pkg
        Safe-ExtractArchive -ZipPath $ZipDest -ExtractLocation (Join-Path $MinecraftDir ($Pkg.ToLower())) -IsShaderpack:($Pkg -eq "Shaderpacks")
    }

    Invoke-SecureDownload -Url $Downloads["ServersDat"] -DestinationPath (Join-Path $MinecraftDir "servers.dat") -FileName "Servers"
    Invoke-SecureDownload -Url $Downloads["Manifest"] -DestinationPath (Join-Path $MinecraftDir "manifest.json") -FileName "Manifest"

    Configure-OfficialLauncherProfile -SelectedRamGB $ChosenRam
    Configure-SKLauncherProfile -SelectedRamGB $ChosenRam
}

function Invoke-UpdateWorkflow {
    $ChosenRam = Get-UserRamChoice
    Initialize-Environment
    foreach ($Folder in $UpdateFolders) {
        $TargetPath = Join-Path $MinecraftDir $Folder
        if (Test-Path $TargetPath) { Remove-Item -Path $TargetPath -Recurse -Force -ErrorAction SilentlyContinue }
    }
    foreach ($Pkg in @("Mods", "Config")) {
        $ZipDest = Join-Path $WorkDir "$Pkg.zip"
        Invoke-SecureDownload -Url $Downloads[$Pkg] -DestinationPath $ZipDest -FileName $Pkg
        Safe-ExtractArchive -ZipPath $ZipDest -ExtractLocation (Join-Path $MinecraftDir ($Pkg.ToLower()))
    }
    Invoke-SecureDownload -Url $Downloads["Manifest"] -DestinationPath (Join-Path $MinecraftDir "manifest.json") -FileName "Manifest"
    Configure-OfficialLauncherProfile -SelectedRamGB $ChosenRam
    Configure-SKLauncherProfile -SelectedRamGB $ChosenRam
}

function Invoke-RepairWorkflow {
    Remove-LauncherProfiles
    Clean-ModpackDirectories
    Invoke-FullInstallation
}

function Invoke-Uninstallation {
    Clean-ModpackDirectories
    Remove-LauncherProfiles
    if (Test-Path (Join-Path $VersionsDir $ForgeTargetID)) { Remove-Item -Path (Join-Path $VersionsDir $ForgeTargetID) -Recurse -Force -ErrorAction SilentlyContinue }
    if (Test-Path (Join-Path $MinecraftDir "manifest.json")) { Remove-Item (Join-Path $MinecraftDir "manifest.json") -Force }
}

Check-InitialLauncherSetup

function Show-MainMenu {
    Clear-Host
    Write-Host "`n====================================================================" -ForegroundColor Cyan
    Write-Host "                   INSTALADOR BLACKSTICKX MODPACK                   " -ForegroundColor Cyan
    Write-Host "====================================================================" -ForegroundColor Cyan
    Write-Host "  Versión del Modpack: 1.20.1 | Forge: $ForgeVersion" -ForegroundColor Gray
    Write-Host "  Ruta de Instalación: $MinecraftDir" -ForegroundColor Gray
    Write-Host "--------------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host "  [1] Instalar (Instalación limpia completa + Crear perfil principal)" -ForegroundColor White
    Write-Host ""
    Write-Host "  [2] Actualizar (Solo Mods y Config, mantiene tus opciones)" -ForegroundColor White
    Write-Host ""
    Write-Host "  [3] Reparar (Borrado completo y reinstalación limpia)" -ForegroundColor White
    Write-Host ""
    Write-Host "  [4] Desinstalar (Elimina el modpack y perfiles de forma segura)" -ForegroundColor White
    Write-Host ""
    Write-Host "  [5] Abrir Carpeta .minecraft" -ForegroundColor White
    Write-Host ""
    Write-Host "  [6] Salir" -ForegroundColor White
    Write-Host "====================================================================" -ForegroundColor Cyan
    Write-Host ""
}

do {
    Show-MainMenu
    $Choice = Read-Host "  Selecciona una opción [1-6]"
    
    try {
        switch ($Choice) {
            "1" {
                Invoke-FullInstallation
                Write-Host "`n¡Instalación completada con el icono personalizado!" -ForegroundColor Green
                [void]$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            "2" {
                Invoke-UpdateWorkflow
                Write-Host "`n¡Actualización completada!" -ForegroundColor Green
                [void]$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            "3" {
                Invoke-RepairWorkflow
                Write-Host "`n¡Reparación completada!" -ForegroundColor Green
                [void]$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            "4" {
                Invoke-Uninstallation
                Write-Host "`nDesinstalado con éxito." -ForegroundColor Green
                [void]$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            "5" {
                Start-Process explorer.exe -ArgumentList "`"$MinecraftDir`""
            }
            "6" {
                break
            }
        }
    }
    catch {
        Write-Host "`nOcurrió un error. Revisa el log en: $LogPath" -ForegroundColor Red
        [void]$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
} while ($Choice -ne "6")
