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

# Icono del Perfil en Base64
$IconBase64 = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAIAAAACACAYAAADDPmHLAAAMnUlEQVR4nO2dC1QVxxnH/xcBSQRqFCMQVEDSJqk2SKFiGqOoaVNrarKssagnJCcnsac1SdPq0WhOW09jajRRT2xz0oj4rG+tMa1RtDWW1hqi+AYfhYgiKCI+BbyX6RevelYSvPEjGEeW6a8c049qaaDoSvMlMWzTpqrAhw3LIjU1F10U1sg6hOfJmDHZ7TJ껑aanOkk3WzMewZ0+Z7bBw2Nl6eG9fL3a2z4W2PcfXN7w9QWl+n8aZl5s5V6M+PExJ8Xl10tPz20n/W4eFz4O4M2X3vI0lKStKy0n//O7rS5zZ7Vd+7v8lWzL59n+WwP683P3p45u53yR03g+q8vLh7nZ10M3oM/4fG6d5r+uK7V1W2M70wUo9v3e74rO+Yy1sP13+VzH4u9v7M8uYJvjZc3v1e8r9o7UjW0X/673/h7/ZqA+V5/0Zf8eG2uW7y/P//JcM6D2Y2X5YQpW3bWbV/5o89650d/+7P5s+f9P7b8P+Gf4wAAAABJRU5ErkJggg=="

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
        
        # Caso especial para shaders: evita crear subcarpetas anidadas si el zip contiene una carpeta con el mismo nombre
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

            # Comprobar si se extrajo dentro de una única carpeta contenedora
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

        if (-not $FoundOfficial) {
            Write-Host "  [!] No se detectó el Minecraft original en las rutas comunes." -ForegroundColor Yellow
            Write-Log "Minecraft Original indicado pero no hallado físicamente." "WARN"
        }
    } 
    else {
        Write-Log "El usuario indicó que NO tiene Minecraft original. Verificando SKLauncher..." "INFO"
        
        if (Test-Path $SKLauncherJarPath) {
            Write-Host "  SKLauncher detectado en: $SKLauncherJarPath" -ForegroundColor Green
            Write-Log "SKLauncher detectado en: $SKLauncherJarPath" "SUCCESS"
        } else {
            Write-Host "  SKLauncher no encontrado en la ruta exacta. Procediendo a instalarlo..." -ForegroundColor Yellow
            Write-Log "SKLauncher no hallado en $SKLauncherJarPath. Iniciando instalador..." "WARN"
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
        
        Write-Host "  [i] Se abrirá el instalador de SKLauncher. Por favor, instálalo." -ForegroundColor Yellow
        Write-Host "  [i] Este script esperará hasta que detecte el archivo JAR principal..." -ForegroundColor Cyan
        Write-Log "Ejecutando instalador de SKLauncher de forma interactiva..." "INFO"
        
        Start-Process -FilePath $InstallerDest -Wait

        $TimeoutSeconds = 600
        $Elapsed = 0

        while ($Elapsed -lt $TimeoutSeconds) {
            if (Test-Path $SKLauncherJarPath) {
                Write-Host "  ¡SKLauncher detectado con éxito en su ruta final!" -ForegroundColor Green
                Write-Log "SKLauncher detectado en $SKLauncherJarPath tras la instalación." "SUCCESS"
                return
            }
            Start-Sleep -Seconds 4
            $Elapsed += 4
        }
        
        Write-Log "Tiempo de espera agotado para SKLauncher." "WARN"
    }
    catch {
        Write-Log "Error al gestionar la instalación de SKLauncher: $_" "ERROR"
    }
}

function Get-UserRamChoice {
    Write-Log "Detectando memoria RAM física del sistema..." "INFO"
    
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
        if (-not $Options.ContainsKey($Selection)) {
            Write-Host "  Opción inválida. Inténtalo de nuevo." -ForegroundColor Red
        }
    }

    $SelectedRam = $Options[$Selection]
    Write-Log "El usuario seleccionó asignar $SelectedRam GB de RAM al cliente." "SUCCESS"
    return $SelectedRam
}

function Configure-OfficialLauncherProfile {
    Param (
        [int]$SelectedRamGB = 8
    )
    Write-Log "Configurando el perfil 'blackstickx' como principal en launcher_profiles.json..." "INFO"
    
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
        catch {
            Write-Log "No se pudo leer launcher_profiles.json, se creará una estructura nueva." "WARN"
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
            $isGenericForge = ($pData.lastVersionId -eq $TargetForgeVersion)
            
            if (-not $isGenericForge) {
                $ProfilesDict[$pName] = $pData
            } else {
                Write-Log "Removiendo perfil automático residual de Forge ($pName)..." "INFO"
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
        Write-Log "Perfil 'blackstickx' configurado como principal y en la primera posición." "SUCCESS"
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
    Write-Log "Configurando subsistema de perfiles para SKLauncher..." "INFO"
    
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
        "name"             = "BlackStickX Server"
        "version"          = $TargetForgeVersion
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
            Write-Log "El archivo profiles.json de SKLauncher no se pudo leer o estaba dañado." "WARN"
        }
    }

    $ProfilesStructure = [ordered]@{
        "profiles" = $ProfilesList.ToArray()
    }

    $Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    $JsonOutput = ConvertTo-Json $ProfilesStructure -Depth 10
    [System.IO.File]::WriteAllText($SKJsonPath, $JsonOutput, $Utf8NoBom)

    Write-Log "Perfil 'BlackStickX Server' sincronizado y colocado primero en SKLauncher con ${SelectedRamGB}GB de RAM." "SUCCESS"
}

function Remove-LauncherProfiles {
    Write-Log "Removiendo perfiles de los launchers..." "INFO"
    
    $ProfileID = "blackstickx"
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
                    Write-Log "Perfil 'blackstickx' eliminado de launcher_profiles.json correctamente." "SUCCESS"
                }
            }
        }
        catch {
            Write-Log "No se pudo modificar launcher_profiles.json durante la desinstalación." "WARN"
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
                    Write-Log "Perfil eliminado de SKLauncher correctamente." "SUCCESS"
                }
            }
        }
        catch {
            Write-Log "No se pudo modificar profiles.json de SKLauncher durante la desinstalación." "WARN"
        }
    }
}

function Get-Java18Binary {
    Write-Log "Buscando instalación de Java 18 en el sistema..." "INFO"
    
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
                            Write-Log "Java 18 detectado en Registro: $PathToCheck" "SUCCESS"
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
                    Write-Log "Java 18 detectado en archivos locales: $($Exe.FullName)" "SUCCESS"
                    return $Exe.FullName
                }
            }
        }
    }

    if (Get-Command java -ErrorAction SilentlyContinue) {
        $SysVersion = & java -version 2>&1 | Out-String
        if ($SysVersion -match 'version "18\.') {
            $Path = (Get-Command java).Source
            Write-Log "Java 18 activo en la variable PATH: $Path" "SUCCESS"
            return $Path
        }
    }

    return $null
}

function Ensure-Java18Environment {
    $JavaPath = Get-Java18Binary
    if ($JavaPath -eq $null) {
        Write-Log "Java 18 no detectado. Iniciando instalación automática..." "WARN"
        $LocalJavaExe = Join-Path $WorkDir "jdk18_installer.exe"
        Invoke-SecureDownload -Url $Downloads["Java18"] -DestinationPath $LocalJavaExe -FileName "Instalador de Java 18"
        
        Write-Log "Ejecutando instalador de Java 18 en modo silencioso..." "INFO"
        $Process = Start-Process -FilePath $LocalJavaExe -ArgumentList "/s" -PassThru -Wait
        
        $JavaPath = Get-Java18Binary
        if ($JavaPath -eq $null) {
            Write-Log "Error crítico: Se instaló Java 18 pero el sistema no pudo verificarlo." "ERROR"
            throw "Error de dependencia: Java 18 ausente."
        }
    }
    return $JavaPath
}

function Get-ForgeInstallationStatus {
    $ExpectedJson = Join-Path $VersionsDir "$ForgeTargetID\$ForgeTargetID.json"
    if (Test-Path $ExpectedJson) {
        return $true
    }
    return $false
}

function Remove-ForgeVersionFolder {
    $ForgeVersionFolder = Join-Path $VersionsDir $ForgeTargetID
    if (Test-Path $ForgeVersionFolder) {
        try {
            Write-Log "Eliminando la versión de Forge existente ($ForgeTargetID)..." "INFO"
            Remove-Item -Path $ForgeVersionFolder -Recurse -Force
            Write-Log "Versión de Forge removida correctamente." "SUCCESS"
        }
        catch {
            Write-Log "No se pudo borrar la carpeta $ForgeTargetID. Revisa si Minecraft está abierto." "WARN"
        }
    }
}

function Ensure-ForgeEnvironment {
    Param([string]$JavaExecutable)
    
    Remove-ForgeVersionFolder

    $LocalForgeJar = Join-Path $WorkDir "forge_installer.jar"
    Write-Log "Iniciando descarga del instalador oficial Forge $ForgeVersion..." "INFO"
    Invoke-SecureDownload -Url $Downloads["Forge"] -DestinationPath $LocalForgeJar -FileName "Instalador de Forge"
    
    Write-Log "Ejecutando la instalación automatizada de Forge en MODO CLIENTE..." "INFO"

    $ArgumentList = "-jar `"$LocalForgeJar`" --installClient `"$MinecraftDir`""
    $Process = Start-Process -FilePath $JavaExecutable -ArgumentList $ArgumentList -WorkingDirectory $WorkDir -PassThru -Wait -NoNewWindow

    if (-not (Get-ForgeInstallationStatus)) {
        Write-Log "No se completó la instalación de Forge." "ERROR"
        throw "La instalación de Forge Cliente falló o fue cancelada."
    }
    Write-Log "Forge Cliente (1.20.1-47.4.22) se ha instalado y verificado correctamente en $VersionsDir\$ForgeTargetID." "SUCCESS"
}

function Clean-ModpackDirectories {
    Write-Log "Limpiando directorios antiguos del modpack..." "INFO"
    foreach ($Folder in $ModpackFolders) {
        $TargetPath = Join-Path $MinecraftDir $Folder
        if (Test-Path $TargetPath) {
            try {
                Remove-Item -Path $TargetPath -Recurse -Force
                Write-Log "Carpeta purgada: /$Folder" "INFO"
            }
            catch {
                Write-Log "No se pudo eliminar la carpeta $Folder. Asegúrate de que Minecraft no esté abierto." "WARN"
            }
        }
    }
    Write-Log "Fase de limpieza completada." "SUCCESS"
}

function Invoke-FullInstallation {
    Write-Log "=========================================" "INFO"
    Write-Log "INICIANDO INSTALACIÓN COMPLETA DE BLACKSTICKX" "INFO"
    Write-Log "=========================================" "INFO"
    
    $ChosenRam = Get-UserRamChoice
    
    Initialize-Environment
    $JavaPath = Ensure-Java18Environment
    Ensure-ForgeEnvironment -JavaExecutable $JavaPath
    Clean-ModpackDirectories

    $Packages = @("Mods", "Config", "Defaultconfigs", "KubeJS", "Resourcepacks", "Shaderpacks")
    foreach ($Pkg in $Packages) {
        $ZipDest = Join-Path $WorkDir "$Pkg.zip"
        Invoke-SecureDownload -Url $Downloads[$Pkg] -DestinationPath $ZipDest -FileName "Paquete $Pkg"
        
        $TargetFolder = Join-Path $MinecraftDir ($Pkg.ToLower())
        
        if ($Pkg -eq "Shaderpacks") {
            Safe-ExtractArchive -ZipPath $ZipDest -ExtractLocation $TargetFolder -IsShaderpack
        } else {
            Safe-ExtractArchive -ZipPath $ZipDest -ExtractLocation $TargetFolder
        }
    }

    $ServerDatPath = Join-Path $MinecraftDir "servers.dat"
    Invoke-SecureDownload -Url $Downloads["ServersDat"] -DestinationPath $ServerDatPath -FileName "Lista de Servidores"

    $ManifestPath = Join-Path $MinecraftDir "manifest.json"
    Invoke-SecureDownload -Url $Downloads["Manifest"] -DestinationPath $ManifestPath -FileName "Manifiesto del Modpack"

    Configure-OfficialLauncherProfile -SelectedRamGB $ChosenRam
    Configure-SKLauncherProfile -SelectedRamGB $ChosenRam

    Write-Log "¡Proceso de instalación completado con éxito!" "SUCCESS"
}

function Invoke-UpdateWorkflow {
    Write-Log "=========================================" "INFO"
    Write-Log "INICIANDO ACTUALIZACIÓN (SOLO MODS Y CONFIG)" "INFO"
    Write-Log "=========================================" "INFO"
    
    $ChosenRam = Get-UserRamChoice
    
    Initialize-Environment
    
    foreach ($Folder in $UpdateFolders) {
        $TargetPath = Join-Path $MinecraftDir $Folder
        if (Test-Path $TargetPath) {
            try {
                Remove-Item -Path $TargetPath -Recurse -Force
                Write-Log "Carpeta purgada: /$Folder" "INFO"
            }
            catch {
                Write-Log "No se pudo limpiar /$Folder. Revisa si Minecraft está abierto." "WARN"
            }
        }
    }
    
    $Packages = @("Mods", "Config")
    foreach ($Pkg in $Packages) {
        $ZipDest = Join-Path $WorkDir "$Pkg.zip"
        Invoke-SecureDownload -Url $Downloads[$Pkg] -DestinationPath $ZipDest -FileName "Paquete $Pkg"
        
        $TargetFolder = Join-Path $MinecraftDir ($Pkg.ToLower())
        Safe-ExtractArchive -ZipPath $ZipDest -ExtractLocation $TargetFolder
    }

    $ManifestPath = Join-Path $MinecraftDir "manifest.json"
    Invoke-SecureDownload -Url $Downloads["Manifest"] -DestinationPath $ManifestPath -FileName "Manifiesto de Actualización"
    
    Configure-OfficialLauncherProfile -SelectedRamGB $ChosenRam
    Configure-SKLauncherProfile -SelectedRamGB $ChosenRam

    Write-Log "Actualización de Mods y Config completada." "SUCCESS"
}

function Invoke-RepairWorkflow {
    Write-Log "=========================================" "INFO"
    Write-Log "INICIANDO REPARACIÓN Y REINSTALACIÓN COMPLETA" "INFO"
    Write-Log "=========================================" "INFO"
    
    Write-Log "Paso 1: Eliminando perfiles y carpetas existentes..." "WARN"
    Invoke-Uninstallation
    
    Write-Log "Paso 2: Iniciando instalación desde cero..." "INFO"
    Invoke-FullInstallation

    Write-Log "Reparación completada. Todos los datos fueron reinstalados limpiamente." "SUCCESS"
}

function Invoke-Uninstallation {
    Write-Log "=========================================" "INFO"
    Write-Log "INICIANDO DESINSTALACIÓN DE BLACKSTICKX" "INFO"
    Write-Log "=========================================" "INFO"
    
    Clean-ModpackDirectories
    Remove-LauncherProfiles
    Remove-ForgeVersionFolder

    $ManifestPath = Join-Path $MinecraftDir "manifest.json"
    if (Test-Path $ManifestPath) { 
        Remove-Item $ManifestPath -Force 
        Write-Log "Manifiesto eliminado." "INFO"
    }
    
    Write-Log "El modpack y sus perfiles asociados se han desinstalado correctamente." "SUCCESS"
}

# -----------------------------------------------------------------
# FLUJO PRINCIPAL Y MENÚ
# -----------------------------------------------------------------
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
                Write-Host "`n¡Instalación completada!" -ForegroundColor Green
                Write-Host "El perfil 'BlackStickX Server' está configurado de primero y listo para jugar." -ForegroundColor Green
                Write-Host "Presiona cualquier tecla para volver al menú principal..." -ForegroundColor White
                [void]$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            "2" {
                Invoke-UpdateWorkflow
                Write-Host "`n¡Actualización completada! Presiona cualquier tecla para continuar..." -ForegroundColor Green
                [void]$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            "3" {
                Invoke-RepairWorkflow
                Write-Host "`n¡Reparación completada con éxito!" -ForegroundColor Green
                Write-Host "Presiona cualquier tecla para continuar..." -ForegroundColor White
                [void]$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            "4" {
                Invoke-Uninstallation
                Write-Host "`nModpack y perfiles desinstalados con éxito. Presiona cualquier tecla para continuar..." -ForegroundColor Green
                [void]$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            "5" {
                Write-Log "Abriendo la carpeta .minecraft en el Explorador de Windows..." "INFO"
                Start-Process explorer.exe -ArgumentList "`"$MinecraftDir`""
            }
            "6" {
                Write-Log "Cerrando el instalador..." "INFO"
                break
            }
            Default {
                Write-Host "Opción no válida. Elige un número del menú." -ForegroundColor Yellow
                Start-Sleep -Seconds 2
            }
        }
    }
    catch {
        Write-Host "`nSe produjo un error crítico durante el proceso." -ForegroundColor Red
        Write-Host "Consulta los detalles del error en: $LogPath" -ForegroundColor Yellow
        Write-Host "Presiona cualquier tecla para regresar al menú..." -ForegroundColor White
        [void]$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
    
} while ($Choice -ne "6")
