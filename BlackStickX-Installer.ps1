# =================================================================
# HERRAMIENTA DE INSTALACIÓN Y GESTIÓN AUTOMÁTICA - BLACKSTICKX MODPACK
# Entorno Objetivo: Windows 10 / Windows 11
# Shell Soportado: PowerShell 5.0+
# =================================================================

$ErrorActionPreference = "Stop"

# 1. FORZAR PROTOCOLOS DE SEGURIDAD TLS 1.2 / TLS 1.3 (Evita 'Conexión terminada de forma inesperada')
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

# 2. CONFIGURACIÓN DE CODIFICACIÓN EN CONSOLA
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Cabecera para imitar un navegador web real
$Global:UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

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
$IconBase64 = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAIAAAACACAYAAADDPmHLAAAMnUlEQVR4nO2dC1QVxxnH/xcBSQRqFCMQVEDSJqk2SKFiGqOoaVNraxKssagnJCcnsac1SdPq0WhOW09jajRRT2xz0oj4rG+tMa1RtDWW1hqi+AYfhYgiKCi+BbyX6RnugPexO7vAvXt378zvnPFxd3Z39vu+ncc3M99CIpFIJBKJRCKRSCQiYQuSZ30CwA8BpALoBoCw5EkogOsASgGUA/gKQCWAowCuBPYRJO3hUQP/c1F4e9NlALSvH4A6oE8AkO4+ACD8/23D3wQ46K3eAcB6APUANB3rWwMAgP9nAMgAK9d+B4D07+N5AADlXJ8HAHBeNwCgAODP43vP6H4A9n77/gBAt4b/A/CBAAD091V73hYAAIAbwP8A4P3+AgAAwP8PAIAwBwEAAMjH34c/3gDAh7W/BQAARAB4ACrLq0oWAAAAAElFTkSuQmCC"

# Directorios principales del modpack
$ModpackFolders = @("mods", "config", "defaultconfigs", "kubejs", "resourcepacks", "shaderpacks")
$UpdateFolders  = @("mods", "config")

# Enlaces de descarga del repositorio
$Downloads = @{
    "Config"                 = "https://github.com/bast1waw/BlackStickX-Modpack/releases/download/v1.0.0/config.zip";
    "Defaultconfigs"         = "https://github.com/bast1waw/BlackStickX-Modpack/releases/download/v1.0.0/defaultconfigs.zip";
    "Forge"                  = "https://maven.minecraftforge.net/net/minecraftforge/forge/1.20.1-47.4.22/forge-1.20.1-47.4.22-installer.jar";
    "Java18"                 = "https://github.com/bast1waw/BlackStickX-Modpack/releases/download/v1.0.0/jdk-18.0.2.1_windows-x64_bin.exe";
    "Java21"                 = "https://github.com/bast1waw/BlackStickX-Modpack/releases/download/v1.0.0/jdk-21.0.11_windows-x64_bin.exe";
    "KubeJS"                 = "https://github.com/bast1waw/BlackStickX-Modpack/releases/download/v1.0.0/kubejs.zip";
    "Manifest"               = "https://github.com/bast1waw/BlackStickX-Modpack/releases/download/v1.0.0/manifest.json";
    "Mods"                   = "https://github.com/bast1waw/BlackStickX-Modpack/releases/download/v1.0.0/mods.zip";
    "Resourcepacks"          = "https://github.com/bast1waw/BlackStickX-Modpack/releases/download/v1.0.0/resourcepacks.zip";
    "ServersDat"             = "https://github.com/bast1waw/BlackStickX-Modpack/releases/download/v1.0.0/servers.dat";
    "Shaderpacks"            = "https://github.com/bast1waw/BlackStickX-Modpack/releases/download/v1.0.0/shaderpacks.zip";
    "SKLauncherJar"          = "https://github.com/bast1waw/BlackStickX-Modpack/releases/download/v1.0.0/SKlauncher-3.2.18.jar";
    "SKLauncherExe"          = "https://github.com/bast1waw/BlackStickX-Modpack/releases/download/v1.0.0/SKlauncher-3.2.18_Setup.exe";
    "SKLauncherJarOfficial"  = "https://github.com/skmedix/sklauncher/releases/latest/download/SKlauncher.jar"
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
# FUNCIONES DE DESCARGA Y ENTORNO
# -----------------------------------------------------------------
function Initialize-Environment {
    # Crea todas las carpetas necesarias antes de cualquier descarga
    $FoldersToCreate = @($MinecraftDir, $WorkDir, $SKLauncherDir)
    foreach ($Folder in $FoldersToCreate) {
        if (-not (Test-Path $Folder)) {
            New-Item -ItemType Directory -Path $Folder -Force | Out-Null
        }
    }
}

function Invoke-SecureDownload {
    Param (
        [string]$Url,
        [string]$DestinationPath,
        [string]$FileName
    )
    Write-Log "Descargando $FileName..." "INFO"
    
    # Asegurar la existencia de la carpeta contenedora del archivo destino
    $ParentFolder = Split-Path $DestinationPath -Parent
    if (-not (Test-Path $ParentFolder)) {
        New-Item -ItemType Directory -Path $ParentFolder -Force | Out-Null
    }

    # Intento de descarga usando la clase .NET WebClient (no es bloqueada por GitHub)
    try {
        $WebClient = New-Object System.Net.WebClient
        $WebClient.Headers.Add("User-Agent", $Global:UserAgent)
        $WebClient.DownloadFile($Url, $DestinationPath)
        Write-Log "Descarga exitosa: $FileName" "SUCCESS"
    }
    catch {
        # Respaldo secundario mediante BITS / PowerShell puro
        try {
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $Url -OutFile $DestinationPath -UserAgent $Global:UserAgent -UseBasicParsing -ErrorAction Stop
            Write-Log "Descarga exitosa (Método Secundario): $FileName" "SUCCESS"
        }
        catch {
            Write-Log "Error al descargar $FileName desde $Url. Detalles: $_" "ERROR"
            throw $_
        }
    }
}

function Safe-ExtractArchive {
    Param (
        [string]$ZipPath,
        [string]$ExtractLocation,
        [switch]$IsShaderpack
    )
    Write-Log "Extrayendo $(Split-Path $ZipPath -Leaf)..." "INFO"
    try {
        if (-not (Test-Path $ExtractLocation)) {
            New-Item -ItemType Directory -Path $ExtractLocation -Force | Out-Null
        }
        
        if ($IsShaderpack) {
            $TempExtractDir = Join-Path $WorkDir "temp_shaders_extract"
            if (Test-Path $TempExtractDir) { Remove-Item $TempExtractDir -Recurse -Force }
            New-Item -ItemType Directory -Path $TempExtractDir -Force | Out-Null

            Expand-Archive -Path $ZipPath -DestinationPath $TempExtractDir -Force

            $SubItems = Get-ChildItem -Path $TempExtractDir
            if ($SubItems.Count -eq 1 -and $SubItems[0].PSIsContainer) {
                Get-ChildItem -Path $SubItems[0].FullName | Move-Item -Destination $ExtractLocation -Force
            } else {
                Get-ChildItem -Path $TempExtractDir | Move-Item -Destination $ExtractLocation -Force
            }
            Remove-Item -Path $TempExtractDir -Recurse -Force -ErrorAction SilentlyContinue
        } 
        else {
            Expand-Archive -Path $ZipPath -DestinationPath $ExtractLocation -Force
        }
    }
    catch {
        Write-Log "Error durante la extracción: $_" "ERROR"
        throw $_
    }
}

# -----------------------------------------------------------------
# FLUJO DE INSTALACIÓN DE SKLAUNCHER Y VERIFICACIÓN
# -----------------------------------------------------------------
function Deploy-SKLauncherAndWait {
    Write-Log "Descargando e instalando SKLauncher automáticamente..." "INFO"
    
    $InstallerDest = Join-Path $WorkDir "SKlauncher_Setup.exe"
    $Downloaded = $false

    # 1. Intentar el ejecutable de tu Release
    try {
        Invoke-SecureDownload -Url $Downloads["SKLauncherExe"] -DestinationPath $InstallerDest -FileName "Instalador SKLauncher (.exe)"
        $Downloaded = $true
    }
    catch {
        Write-Log "Aviso: No se pudo bajar el .exe. Intentando bajar .jar..." "WARN"
    }

    # 2. Si no bajó el ejecutable, descargar el .jar oficial
    if (-not $Downloaded) {
        try {
            Invoke-SecureDownload -Url $Downloads["SKLauncherJarOfficial"] -DestinationPath $SKLauncherJarPath -FileName "SKLauncher Oficial (.jar)"
            Write-Host "  ¡SKLauncher (.jar) descargado y listo!" -ForegroundColor Green
            return
        }
        catch {
            # 3. Descargar el .jar directo de tu repositorio
            try {
                Invoke-SecureDownload -Url $Downloads["SKLauncherJar"] -DestinationPath $SKLauncherJarPath -FileName "SKLauncher Backup (.jar)"
                Write-Host "  ¡SKLauncher (.jar) descargado y listo!" -ForegroundColor Green
                return
            }
            catch {
                Write-Log "Error crítico: Fallaron todas las opciones de descarga de SKLauncher." "ERROR"
                throw $_
            }
        }
    }

    # Ejecución silenciosa si bajó el ejecutable
    if (Test-Path $InstallerDest) {
        try {
            Write-Log "Ejecutando instalador de SKLauncher..." "INFO"
            Start-Process -FilePath $InstallerDest -Wait

            # Esperar a que quede instalado el .jar
            $Timeout = 60
            $Elapsed = 0
            while ($Elapsed -lt $Timeout) {
                if (Test-Path $SKLauncherJarPath) {
                    Write-Host "  ¡SKLauncher instalado correctamente!" -ForegroundColor Green
                    return
                }
                Start-Sleep -Seconds 2
                $Elapsed += 2
            }
        }
        catch {
            Write-Log "Error al ejecutar el instalador: $_" "ERROR"
            throw $_
        }
    }
}

function Check-InitialLauncherSetup {
    Clear-Host
    Initialize-Environment

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
        Write-Log "El usuario indicó que tiene Minecraft original." "INFO"
    } 
    else {
        Write-Log "El usuario indicó que NO tiene Minecraft original. Verificando SKLauncher..." "INFO"
        
        if (Test-Path $SKLauncherJarPath) {
            Write-Host "  SKLauncher detectado en: $SKLauncherJarPath" -ForegroundColor Green
        } else {
            Write-Host "  SKLauncher no encontrado. Procediendo a instalarlo..." -ForegroundColor Yellow
            Deploy-SKLauncherAndWait
        }
    }

    Write-Host "`n  Verificación completada. Entrando al menú..." -ForegroundColor Cyan
    Start-Sleep -Seconds 2
}

# -----------------------------------------------------------------
# RESTO DE OPCIONES (RAM, CONFIGURACIONES DE PERFIL Y FLUJOS)
# -----------------------------------------------------------------
function Get-UserRamChoice {
    $TotalRamGB = [Math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
    $MaxSafeRam = [Math]::Max(4, [Math]::Floor($TotalRamGB * 0.75))
    $RecommendedRam = if ($TotalRamGB -ge 16) { 8 } elseif ($TotalRamGB -ge 12) { 6 } else { 4 }

    Clear-Host
    Write-Host "====================================================================" -ForegroundColor Cyan
    Write-Host "                CONFIGURACIÓN DE MEMORIA RAM (JVM)                  " -ForegroundColor Cyan
    Write-Host "====================================================================" -ForegroundColor Cyan
    Write-Host "  Tu PC cuenta con: $TotalRamGB GB de RAM total." -ForegroundColor Gray
    Write-Host "--------------------------------------------------------------------" -ForegroundColor Cyan
    
    $Options = @{}
    $Index = 1

    Write-Host "  [$Index] 4 GB  <-- [MÍNIMO]" -ForegroundColor Yellow
    $Options.Add($Index.ToString(), 4)
    $Index++

    if ($RecommendedRam -gt 4 -and $RecommendedRam -le $MaxSafeRam) {
        Write-Host "  [$Index] $RecommendedRam GB  <-- [RECOMENDADO]" -ForegroundColor Green
        $Options.Add($Index.ToString(), $RecommendedRam)
        $Index++
    }

    foreach ($gb in @(6, 8, 12, 16)) {
        if ($gb -le $MaxSafeRam -and $gb -ne 4 -and $gb -ne $RecommendedRam) {
            Write-Host "  [$Index] $gb GB" -ForegroundColor White
            $Options.Add($Index.ToString(), $gb)
            $Index++
        }
    }
    Write-Host "====================================================================" -ForegroundColor Cyan

    $Selection = ""
    while (-not $Options.ContainsKey($Selection)) {
        $Selection = Read-Host "  Selecciona una opción [1-$($Index-1)]"
    }

    return $Options[$Selection]
}

function Configure-OfficialLauncherProfile {
    Param ([int]$SelectedRamGB = 8)
    $JvmArgs = "-Xmx${SelectedRamGB}G -XX:+UnlockExperimentalVMOptions -XX:+UseG1GC -XX:G1NewSizePercent=20 -XX:G1ReservePercent=20 -XX:MaxGCPauseMillis=50 -XX:G1HeapRegionSize=32M"
    $ProfileID = "blackstickx"

    $NewProfile = [ordered]@{
        "created"       = "2026-08-01T00:00:00.000Z"
        "icon"          = $IconBase64
        "javaArgs"      = $JvmArgs
        "lastUsed"      = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ")
        "lastVersionId" = $ForgeTargetID
        "name"          = "BlackStickX Server"
        "type"          = "custom"
    }

    $JsonObject = $null
    if (Test-Path $OfficialProfilesJson) {
        try {
            $RawText = [System.IO.File]::ReadAllText($OfficialProfilesJson)
            if (-not [string]::IsNullOrWhiteSpace($RawText)) { $JsonObject = $RawText | ConvertFrom-Json }
        } catch {}
    }

    if ($null -eq $JsonObject) {
        $JsonObject = [PSCustomObject]@{ profiles = [PSCustomObject]@{}; settings = [PSCustomObject]@{ keepLauncherOpen = $true }; version = 6 }
    }

    $JsonObject | Select-Object -Property * | Add-Member -MemberType NoteProperty -Name "selectedProfile" -Value $ProfileID -Force
    if ($null -eq $JsonObject.profiles) { $JsonObject | Add-Member -MemberType NoteProperty -Name "profiles" -Value ([PSCustomObject]@{}) }

    $ProfilesDict = [ordered]@{}
    $ProfilesDict[$ProfileID] = [PSCustomObject]$NewProfile

    foreach ($prop in (Get-Member -InputObject $JsonObject.profiles -MemberType NoteProperty)) {
        if ($prop.Name -ne $ProfileID) { $ProfilesDict[$prop.Name] = $JsonObject.profiles.$($prop.Name) }
    }

    $JsonObject.profiles = $ProfilesDict
    [System.IO.File]::WriteAllText($OfficialProfilesJson, (ConvertTo-Json $JsonObject -Depth 10), (New-Object System.Text.UTF8Encoding($false)))
}

function Configure-SKLauncherProfile {
    Param ([int]$SelectedRamGB = 4)
    $SKJsonPath = Join-Path $SKLauncherDir "profiles.json"
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
            $ParsedJson = (Get-Content $SKJsonPath -Raw) | ConvertFrom-Json
            if ($null -ne $ParsedJson.profiles) {
                foreach ($p in $ParsedJson.profiles) {
                    if ($p.id -ne $TargetProfileId) { $ProfilesList.Add($p) }
                }
            }
        } catch {}
    }

    $ProfilesStructure = [ordered]@{ "profiles" = $ProfilesList.ToArray() }
    [System.IO.File]::WriteAllText($SKJsonPath, (ConvertTo-Json $ProfilesStructure -Depth 10), (New-Object System.Text.UTF8Encoding($false)))
}

function Get-Java18Binary {
    foreach ($Folder in @("$env:ProgramFiles\Java", "${env:ProgramFiles(x86)}\Java", "$env:ProgramFiles\Eclipse Foundation")) {
        if (Test-Path $Folder) {
            foreach ($Exe in (Get-ChildItem -Path $Folder -Filter "java.exe" -Recurse -ErrorAction SilentlyContinue)) {
                if ([System.Diagnostics.FileVersionInfo]::GetVersionInfo($Exe.FullName).ProductVersion -match "^18\.") { return $Exe.FullName }
            }
        }
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

# -----------------------------------------------------------------
# INICIO Y MENÚ PRINCIPAL
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
                Write-Host "`n¡Instalación completada correctamente!" -ForegroundColor Green
                [void]$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            "2" {
                Invoke-UpdateWorkflow
                Write-Host "`n¡Actualización completada!" -ForegroundColor Green
                [void]$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            "3" {
                Clean-ModpackDirectories
                Invoke-FullInstallation
                Write-Host "`n¡Reparación completada!" -ForegroundColor Green
                [void]$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            "4" {
                Clean-ModpackDirectories
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
        Write-Host "`nOcurrió un error. Consulta el registro en: $LogPath" -ForegroundColor Red
        [void]$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
} while ($Choice -ne "6")
