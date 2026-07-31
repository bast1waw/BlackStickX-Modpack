# =================================================================
# HERRAMIENTA DE INSTALACIÓN Y GESTIÓN AUTOMÁTICA - BLACKSTICKX MODPACK
# Entorno Objetivo: Windows 10 / Windows 11
# Shell Soportado: PowerShell 5.0+
# =================================================================

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# -----------------------------------------------------------------
# RUTAS GLOBALES Y CONFIGURACIÓN
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

# Directorios principales del modpack para gestionar
$ModpackFolders = @("mods", "config", "defaultconfigs", "kubejs", "resourcepacks", "shaderpacks")

# Objetivos específicos para el subsistema de actualización (Solo Mods y Config)
$UpdateFolders = @("mods", "config")

# Manifiesto de URLs de descarga
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
# FUNCIONES PRINCIPALES DE UTILIDAD
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
    Write-Log "Descargando $FileName (Modo de alta velocidad)..." "INFO"
    
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
        [string]$ExtractLocation
    )
    Write-Log "Extrayendo paquete $(Split-Path $ZipPath -Leaf)..." "INFO"
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
        Write-Log "Error durante la extracción del paquete: $_" "ERROR"
        throw $_
    }
}

# -----------------------------------------------------------------
# SUBSISTEMA DE GESTIÓN DINÁMICA DE MEMORIA RAM
# -----------------------------------------------------------------
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
# CONFIGURACIÓN DE PERFILES DE LAUNCHERS (PREMIUM Y NO-PREMIUM)
# -----------------------------------------------------------------
function Configure-OfficialLauncherProfile {
    Param (
        [int]$SelectedRamGB = 8
    )
    Write-Log "Configurando el perfil en launcher_profiles.json..." "INFO"
    
    $TargetForgeVersion = if ($script:ForgeTargetID) { $script:ForgeTargetID } else { "1.20.1-forge-47.4.22" }
    $ProfilesJsonPath   = if ($script:OfficialProfilesJson) { $script:OfficialProfilesJson } else { Join-Path $env:APPDATA ".minecraft\launcher_profiles.json" }

    # Icono en Base64
    $IconBase64 = "data:image/png;base64,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"
    
    $JvmArgs   = "-Xmx${SelectedRamGB}G -XX:+UnlockExperimentalVMOptions -XX:+UseG1GC -XX:G1NewSizePercent=20 -XX:G1ReservePercent=20 -XX:MaxGCPauseMillis=50 -XX:G1HeapRegionSize=32M"
    $ProfileID = "a457530d7be7b05e6a135db4bc9b9a1b"

    $NewProfile = [ordered]@{
        "created"       = "2026-07-31T19:41:10.635Z"
        "icon"          = $IconBase64
        "javaArgs"      = $JvmArgs
        "lastUsed"      = "1970-01-01T00:00:00.000Z"
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

    if ($null -eq $JsonObject.profiles) {
        $JsonObject | Add-Member -MemberType NoteProperty -Name "profiles" -Value ([PSCustomObject]@{})
    }

    # Agregar o actualizar el perfil
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
        Write-Log "Perfil 'BlackStickX Server' actualizado exitosamente en launcher_profiles.json" "SUCCESS"
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

    $ProfilesList.Add($NewProfile)

    $ProfilesStructure = [ordered]@{
        "profiles" = $ProfilesList.ToArray()
    }

    $Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    $JsonOutput = ConvertTo-Json $ProfilesStructure -Depth 10
    [System.IO.File]::WriteAllText($SKJsonPath, $JsonOutput, $Utf8NoBom)

    Write-Log "Perfil 'BlackStickX Server' sincronizado en SKLauncher con ${SelectedRamGB}GB de RAM." "SUCCESS"
}

function Remove-LauncherProfiles {
    Write-Log "Removiendo perfiles de los launchers..." "INFO"
    
    $ProfileID = "a457530d7be7b05e6a135db4bc9b9a1b"
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
                    Write-Log "Perfil eliminado de launcher_profiles.json correctamente." "SUCCESS"
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

function Deploy-SKLauncher {
    Write-Log "Descargando ejecutable de SKLauncher..." "INFO"
    $DesktopPath = [Environment]::GetFolderPath("Desktop")
    $LauncherDest = Join-Path $DesktopPath "SKlauncher.exe"
    
    if (-not (Test-Path $LauncherDest)) {
        Invoke-SecureDownload -Url $Downloads["SKLauncherExe"] -DestinationPath $LauncherDest -FileName "Ejecutable de SKLauncher"
        Write-Log "Acceso directo de SKLauncher descargado en el Escritorio." "SUCCESS"
    } else {
        Write-Log "El ejecutable de SKLauncher ya existe en el Escritorio. Omitiendo descarga." "INFO"
    }
}

# -----------------------------------------------------------------
# SUBSISTEMAS DE ENTORNO (VALIDACIÓN DE JAVA Y FORGE)
# -----------------------------------------------------------------
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

# -----------------------------------------------------------------
# CONTROLADORES DE LIMPIEZA
# -----------------------------------------------------------------
function Get-ForgeInstallationStatus {
    $ExpectedJson = Join-Path $VersionsDir "$ForgeTargetID\$ForgeTargetID.json"
    if (Test-Path $ExpectedJson) {
        Write-Log "Instalación de Forge detectada: $ForgeTargetID" "SUCCESS"
        return $true
    }
    Write-Log "No se encontró el perfil de Forge ($ForgeTargetID)." "WARN"
    return $false
}

function Ensure-ForgeEnvironment {
    Param([string]$JavaExecutable)
    
    if (-not (Get-ForgeInstallationStatus)) {
        Write-Log "Iniciando instalación de Forge $ForgeVersion..." "INFO"
        $LocalForgeJar = Join-Path $WorkDir "forge_installer.jar"
        Invoke-SecureDownload -Url $Downloads["Forge"] -DestinationPath $LocalForgeJar -FileName "Instalador de Forge"
        
        Write-Log "Ejecutando instalador de cliente Forge..." "INFO"
        $ArgumentList = "-jar `"$LocalForgeJar`" --installClient"
        
        $Process = Start-Process -FilePath $JavaExecutable -ArgumentList $ArgumentList -WorkingDirectory $WorkDir -PassThru -Wait
        
        if (-not (Get-ForgeInstallationStatus)) {
            Write-Log "Error en la instalación de Forge." "ERROR"
            throw "Fallo en la instalación de Forge."
        }
        Write-Log "Forge fue instalado correctamente." "SUCCESS"
    }
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

# -----------------------------------------------------------------
# RUTINAS PRINCIPALES (INSTALAR / ACTUALIZAR / REPARAR / DESINSTALAR)
# -----------------------------------------------------------------
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
        Safe-ExtractArchive -ZipPath $ZipDest -ExtractLocation $TargetFolder
    }

    $ServerDatPath = Join-Path $MinecraftDir "servers.dat"
    Invoke-SecureDownload -Url $Downloads["ServersDat"] -DestinationPath $ServerDatPath -FileName "Lista de Servidores"

    $ManifestPath = Join-Path $MinecraftDir "manifest.json"
    Invoke-SecureDownload -Url $Downloads["Manifest"] -DestinationPath $ManifestPath -FileName "Manifiesto del Modpack"

    Configure-OfficialLauncherProfile -SelectedRamGB $ChosenRam
    Configure-SKLauncherProfile -SelectedRamGB $ChosenRam
    Deploy-SKLauncher

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
    
    $ManifestPath = Join-Path $MinecraftDir "manifest.json"
    if (Test-Path $ManifestPath) { Remove-Item $ManifestPath -Force }
    
    Write-Log "El modpack BlackStickX se ha desinstalado correctamente." "SUCCESS"
}

# -----------------------------------------------------------------
# INTERFAZ DE USUARIO EN CONSOLA
# -----------------------------------------------------------------
function Show-MainMenu {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    
    $Host.UI.RawUI.WindowSize = New-Object System.Management.Automation.Host.Size(85, 28)
    $Host.UI.RawUI.BufferSize = New-Object System.Management.Automation.Host.Size(85, 100)
    
    Clear-Host
    Write-Host "`n====================================================================" -ForegroundColor Cyan
    Write-Host "                   INSTALADOR BLACKSTICKX MODPACK                   " -ForegroundColor Cyan
    Write-Host "====================================================================" -ForegroundColor Cyan
    Write-Host "  Versión del Modpack: 1.20.1 | Forge: $ForgeVersion" -ForegroundColor Gray
    Write-Host "  Ruta de Instalación: $MinecraftDir" -ForegroundColor Gray
    Write-Host "--------------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host "  [1] Instalar (Instalación limpia completa + Crear perfil)" -ForegroundColor White
    Write-Host ""
    Write-Host "  [2] Actualizar (Solo Mods y Config, mantiene tus opciones)" -ForegroundColor White
    Write-Host ""
    Write-Host "  [3] Reparar (Borrado completo y reinstalación limpia)" -ForegroundColor White
    Write-Host ""
    Write-Host "  [4] Desinstalar (Elimina el modpack de forma segura)" -ForegroundColor White
    Write-Host ""
    Write-Host "  [5] Abrir Carpeta .minecraft" -ForegroundColor White
    Write-Host ""
    Write-Host "  [6] Salir" -ForegroundColor White
    Write-Host "====================================================================" -ForegroundColor Cyan
    Write-Host ""
}

# Bucle principal de la aplicación
do {
    Show-MainMenu
    $Choice = Read-Host "  Selecciona una opción [1-6]"
    
    try {
        switch ($Choice) {
            "1" {
                Invoke-FullInstallation
                Write-Host "`n¡Instalación completada!" -ForegroundColor Green
                Write-Host "El perfil 'BlackStickX Server' ha sido añadido a tu launcher_profiles.json con tu icono y RAM seleccionada." -ForegroundColor Green
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
                Write-Host "`nModpack desinstalado con éxito. Presiona cualquier tecla para continuar..." -ForegroundColor Green
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
