# Mole Windows - Windows-Specific Cleanup Module
# Cleans Windows-specific caches: thumbnails, Windows Update, WER, DNS cache, etc.

#Requires -Version 5.1

# Import dependencies
$coreModules = @(
    (Join-Path $PSScriptRoot "..\core\Base.psm1"),
    (Join-Path $PSScriptRoot "..\core\Log.psm1"),
    (Join-Path $PSScriptRoot "..\core\FileOps.psm1"),
    (Join-Path $PSScriptRoot "..\core\Elevation.psm1"),
    (Join-Path $PSScriptRoot "..\core\UI.psm1")
)

foreach ($module in $coreModules) {
    Import-Module $module -Force -DisableNameChecking -ErrorAction SilentlyContinue
}

# Prevent multiple loading
if ($script:MOLE_CLEAN_WINDOWS_LOADED) { return }
$script:MOLE_CLEAN_WINDOWS_LOADED = $true

# ============================================================================
# Windows Update Cache
# ============================================================================

function Clear-WindowsUpdateCache {
    <#
    .SYNOPSIS
        Cleans Windows Update download cache.
    .DESCRIPTION
        Removes downloaded Windows Update files. Requires admin privileges.
    #>
    Start-MoleSection -Title "Windows Update Cache"

    $wuPath = Join-Path $env:SystemRoot "SoftwareDistribution\Download"

    if (-not (Test-IsElevated)) {
        Write-Host "  $($script:GRAY)Requires admin - skipping Windows Update cache$($script:NC)"
        Stop-MoleSection
        return @{ CleanedSize = 0; RequiresAdmin = $true }
    }

    if (Test-Path $wuPath) {
        $size = Invoke-SafeClean -Path "$wuPath\*" -Description "Windows Update downloads"
        Stop-MoleSection
        return @{ CleanedSize = $size }
    }

    Stop-MoleSection
    return @{ CleanedSize = 0 }
}

# ============================================================================
# System Temp Files
# ============================================================================

function Clear-SystemTemp {
    <#
    .SYNOPSIS
        Cleans system-level temp files.
    .DESCRIPTION
        Removes old files from C:\Windows\Temp. Requires admin privileges.
    #>
    Start-MoleSection -Title "System Temp Files"

    $systemTemp = Join-Path $env:SystemRoot "Temp"

    if (-not (Test-IsElevated)) {
        Write-Host "  $($script:GRAY)Requires admin - skipping system temp$($script:NC)"
        Stop-MoleSection
        return @{ CleanedSize = 0; RequiresAdmin = $true }
    }

    if (Test-Path $systemTemp) {
        # Only clean files older than 7 days to avoid breaking running processes
        $cutoff = (Get-Date).AddDays(-7)
        $items = Get-ChildItem -Path $systemTemp -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt $cutoff }

        $totalSize = 0
        foreach ($item in $items) {
            $size = Get-PathSize -Path $item.FullName
            if (Remove-MolePath -Path $item.FullName -Silent) {
                $totalSize += $size
            }
        }

        if ($totalSize -gt 0) {
            Set-MoleActivity
            if (Get-MoleDryRun) {
                Write-MoleDryRun "System temp - would clean $(Format-ByteSize -Bytes $totalSize)"
            }
            else {
                Write-MoleSuccess "System temp - cleaned $(Format-ByteSize -Bytes $totalSize)"
            }
        }

        Stop-MoleSection
        return @{ CleanedSize = $totalSize }
    }

    Stop-MoleSection
    return @{ CleanedSize = 0 }
}

# ============================================================================
# Windows Error Reports
# ============================================================================

function Clear-WindowsErrorReports {
    <#
    .SYNOPSIS
        Cleans Windows Error Reporting files.
    #>
    Start-MoleSection -Title "Windows Error Reports"

    $totalSize = 0

    # User-level WER
    $userWer = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\WER"
    if (Test-Path $userWer) {
        $size = Invoke-SafeClean -Path "$userWer\*" -Description "User error reports"
        $totalSize += $size
    }

    # System-level WER (requires admin)
    $systemWer = Join-Path $env:ProgramData "Microsoft\Windows\WER"
    if (Test-Path $systemWer) {
        if (Test-IsElevated) {
            $size = Invoke-SafeClean -Path "$systemWer\ReportQueue\*" -Description "System error report queue"
            $totalSize += $size
            $size = Invoke-SafeClean -Path "$systemWer\ReportArchive\*" -Description "System error report archive"
            $totalSize += $size
        }
        else {
            Write-Host "  $($script:GRAY)System WER requires admin$($script:NC)"
        }
    }

    Stop-MoleSection
    return @{ CleanedSize = $totalSize }
}

# ============================================================================
# DNS Cache
# ============================================================================

function Clear-DnsCache {
    <#
    .SYNOPSIS
        Flushes the Windows DNS resolver cache.
    #>
    Start-MoleSection -Title "DNS Cache"

    if (Get-MoleDryRun) {
        Set-MoleActivity
        Write-MoleDryRun "DNS cache - would flush"
    }
    else {
        try {
            Clear-DnsClientCache -ErrorAction Stop
            Set-MoleActivity
            Write-MoleSuccess "DNS cache flushed"
        }
        catch {
            # Alternative method using ipconfig
            try {
                $null = ipconfig /flushdns 2>$null
                Set-MoleActivity
                Write-MoleSuccess "DNS cache flushed (via ipconfig)"
            }
            catch {
                Write-MoleDebug "Could not flush DNS cache: $($_.Exception.Message)"
            }
        }
    }

    Stop-MoleSection
}

# ============================================================================
# Prefetch Files
# ============================================================================

function Clear-PrefetchFiles {
    <#
    .SYNOPSIS
        Cleans Windows Prefetch files.
    .DESCRIPTION
        Prefetch files help Windows start programs faster, but old ones can be cleaned.
        Requires admin privileges.
    #>
    Start-MoleSection -Title "Prefetch Files"

    $prefetchPath = Join-Path $env:SystemRoot "Prefetch"

    if (-not (Test-IsElevated)) {
        Write-Host "  $($script:GRAY)Requires admin - skipping Prefetch cleanup$($script:NC)"
        Stop-MoleSection
        return @{ CleanedSize = 0; RequiresAdmin = $true }
    }

    if (Test-Path $prefetchPath) {
        # Only clean prefetch files older than 14 days
        $cutoff = (Get-Date).AddDays(-14)
        $items = Get-ChildItem -Path $prefetchPath -Filter "*.pf" -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt $cutoff }

        $totalSize = 0
        foreach ($item in $items) {
            $totalSize += $item.Length
            if (-not (Get-MoleDryRun)) {
                Remove-Item -Path $item.FullName -Force -ErrorAction SilentlyContinue
            }
        }

        if ($totalSize -gt 0) {
            Set-MoleActivity
            if (Get-MoleDryRun) {
                Write-MoleDryRun "Old Prefetch files - would clean $(Format-ByteSize -Bytes $totalSize)"
            }
            else {
                Write-MoleSuccess "Old Prefetch files - cleaned $(Format-ByteSize -Bytes $totalSize)"
            }
        }

        Stop-MoleSection
        return @{ CleanedSize = $totalSize }
    }

    Stop-MoleSection
    return @{ CleanedSize = 0 }
}

# ============================================================================
# Memory Dumps
# ============================================================================

function Clear-MemoryDumps {
    <#
    .SYNOPSIS
        Cleans Windows memory dump files.
    #>
    Start-MoleSection -Title "Memory Dumps"

    $totalSize = 0

    # System memory dumps (requires admin)
    $memoryDmp = Join-Path $env:SystemRoot "MEMORY.DMP"
    if (Test-Path $memoryDmp) {
        if (Test-IsElevated) {
            $size = (Get-Item $memoryDmp).Length
            if (Remove-MolePath -Path $memoryDmp) {
                $totalSize += $size
            }
        }
        else {
            $size = (Get-Item $memoryDmp -ErrorAction SilentlyContinue).Length
            Write-Host "  $($script:GRAY)MEMORY.DMP ($(Format-ByteSize -Bytes $size)) - requires admin$($script:NC)"
        }
    }

    # Minidumps
    $minidumpPath = Join-Path $env:SystemRoot "Minidump"
    if (Test-Path $minidumpPath) {
        if (Test-IsElevated) {
            $size = Invoke-SafeClean -Path "$minidumpPath\*" -Description "Minidump files"
            $totalSize += $size
        }
        else {
            Write-Host "  $($script:GRAY)Minidumps require admin$($script:NC)"
        }
    }

    Stop-MoleSection
    return @{ CleanedSize = $totalSize }
}

# ============================================================================
# Delivery Optimization Cache
# ============================================================================

function Clear-DeliveryOptimization {
    <#
    .SYNOPSIS
        Cleans Windows Delivery Optimization cache.
    #>
    Start-MoleSection -Title "Delivery Optimization"

    $doPath = Join-Path $env:SystemRoot "ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache"

    if (-not (Test-IsElevated)) {
        Write-Host "  $($script:GRAY)Requires admin - skipping Delivery Optimization$($script:NC)"
        Stop-MoleSection
        return @{ CleanedSize = 0; RequiresAdmin = $true }
    }

    if (Test-Path $doPath) {
        $size = Invoke-SafeClean -Path "$doPath\*" -Description "Delivery Optimization cache"
        Stop-MoleSection
        return @{ CleanedSize = $size }
    }

    Stop-MoleSection
    return @{ CleanedSize = 0 }
}

# ============================================================================
# Windows Installer Cache
# ============================================================================

function Clear-WindowsInstallerCache {
    <#
    .SYNOPSIS
        Cleans orphaned Windows Installer patch files.
    .DESCRIPTION
        This is a careful operation - only removes obviously orphaned files.
    #>
    Start-MoleSection -Title "Windows Installer"

    # Note: We intentionally don't clean C:\Windows\Installer as it contains
    # required files for uninstallation. Only clean temp files.

    $installerTemp = Join-Path $env:SystemRoot "Installer\$PatchCache$"
    if (Test-Path $installerTemp -ErrorAction SilentlyContinue) {
        if (Test-IsElevated) {
            # Report size only, don't auto-clean
            $size = Get-PathSize -Path $installerTemp
            if ($size -gt 100MB) {
                Write-Host "  $($script:ICON_LIST) Installer patch cache: $(Format-ByteSize -Bytes $size)"
                Write-Host "    $($script:GRAY)Use Disk Cleanup for safe removal$($script:NC)"
            }
        }
    }

    Stop-MoleSection
}

# ============================================================================
# Font Cache
# ============================================================================

function Clear-SystemFontCache {
    <#
    .SYNOPSIS
        Cleans system font cache.
    #>
    Start-MoleSection -Title "System Font Cache"

    if (-not (Test-IsElevated)) {
        Write-Host "  $($script:GRAY)Requires admin - skipping font cache$($script:NC)"
        Stop-MoleSection
        return
    }

    # Font cache service files
    $fontCachePath = Join-Path $env:SystemRoot "ServiceProfiles\LocalService\AppData\Local\FontCache"
    if (Test-Path $fontCachePath) {
        Invoke-SafeClean -Path "$fontCachePath\*" -Description "System font cache"
    }

    Stop-MoleSection
}

# ============================================================================
# Windows Store Cache
# ============================================================================

function Clear-WindowsStoreCache {
    <#
    .SYNOPSIS
        Cleans Windows Store cache.
    #>
    Start-MoleSection -Title "Windows Store Cache"

    # User-level store cache
    $storeCache = Join-Path $env:LOCALAPPDATA "Packages\*Store*\LocalCache"
    $storeCaches = Get-ChildItem -Path $storeCache -ErrorAction SilentlyContinue

    foreach ($cache in $storeCaches) {
        Invoke-SafeClean -Path "$($cache.FullName)\*" -Description "Windows Store cache"
    }

    # Alternative: run wsreset (without the -i flag which opens Store)
    if (Get-MoleDryRun) {
        Write-MoleDryRun "Windows Store cache reset - would execute"
    }
    else {
        # Note: wsreset.exe clears the cache but also opens the Store app
        # We'll skip this and just clean the cache directories
    }

    Stop-MoleSection
}

# ============================================================================
# Temporary Internet Files
# ============================================================================

function Clear-IECache {
    <#
    .SYNOPSIS
        Cleans Internet Explorer / legacy Edge cache.
    #>
    Start-MoleSection -Title "Internet Explorer Cache"

    # INetCache
    $inetCache = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\INetCache"
    if (Test-Path $inetCache) {
        Invoke-SafeClean -Path "$inetCache\*" -Description "Internet cache"
    }

    # WebCache (WebCacheV01.dat etc.)
    $webCache = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\WebCache"
    # Don't clean - these are locked and managed by Windows

    Stop-MoleSection
}

# ============================================================================
# Windows.old and Previous Installations
# ============================================================================

function Clear-WindowsOld {
    <#
    .SYNOPSIS
        Reports Windows.old folder size (can be 10-30+ GB after updates).
        Actual cleanup should use Disk Cleanup for safety.
    #>
    Start-MoleSection -Title "Windows.old & Upgrade Files"

    $totalSize = 0

    # Windows.old folder
    $windowsOld = "C:\Windows.old"
    if (Test-Path $windowsOld) {
        $size = Get-PathSize -Path $windowsOld
        $totalSize += $size
        if ($size -gt 0) {
            Write-Host "  $($script:ICON_LIST) Windows.old: $($script:YELLOW)$(Format-ByteSize -Bytes $size)$($script:NC)"
            Write-Host "    $($script:GRAY)Remove via Settings > System > Storage > Temporary files$($script:NC)"
        }
    }

    # Windows upgrade folders
    $upgradeFolders = @(
        "C:\`$Windows.~BT",
        "C:\`$Windows.~WS",
        "C:\`$WINDOWS.~Q"
    )
    foreach ($folder in $upgradeFolders) {
        if (Test-Path $folder) {
            $size = Get-PathSize -Path $folder
            $totalSize += $size
            if ($size -gt 100MB) {
                $folderName = Split-Path $folder -Leaf
                Write-Host "  $($script:ICON_LIST) $folderName`: $(Format-ByteSize -Bytes $size)"
            }
        }
    }

    # Windows upgrade logs
    $upgradeLogs = "C:\Windows\Logs\WindowsUpdate"
    if ((Test-Path $upgradeLogs) -and (Test-IsElevated)) {
        Invoke-SafeClean -Path "$upgradeLogs\*.log" -Description "Windows Update logs"
    }

    Stop-MoleSection
    return @{ ReportedSize = $totalSize }
}

# ============================================================================
# Hibernation File
# ============================================================================

function Get-HibernationStatus {
    <#
    .SYNOPSIS
        Reports hibernation file size and status.
        hiberfil.sys can be 40-75% of RAM size.
    #>
    Start-MoleSection -Title "Hibernation File"

    $hiberFile = "C:\hiberfil.sys"
    if (Test-Path $hiberFile -ErrorAction SilentlyContinue) {
        try {
            $size = (Get-Item $hiberFile -Force -ErrorAction Stop).Length
            if ($size -gt 1GB) {
                Write-Host "  $($script:ICON_LIST) hiberfil.sys: $($script:YELLOW)$(Format-ByteSize -Bytes $size)$($script:NC)"
                Write-Host "    $($script:GRAY)Disable hibernation: powercfg /h off (as admin)$($script:NC)"
            }
        }
        catch {
            # File exists but can't read size
            Write-Host "  $($script:ICON_LIST) hiberfil.sys exists (size unknown)"
            Write-Host "    $($script:GRAY)Disable hibernation: powercfg /h off (as admin)$($script:NC)"
        }
    }

    Stop-MoleSection
}

# ============================================================================
# Windows Event Logs
# ============================================================================

function Clear-EventLogs {
    <#
    .SYNOPSIS
        Cleans old Windows Event logs.
    #>
    Start-MoleSection -Title "Windows Event Logs"

    if (-not (Test-IsElevated)) {
        Write-Host "  $($script:GRAY)Requires admin - skipping event logs$($script:NC)"
        Stop-MoleSection
        return
    }

    $logPath = Join-Path $env:SystemRoot "System32\winevt\Logs"
    if (Test-Path $logPath) {
        $size = Get-PathSize -Path $logPath
        if ($size -gt 500MB) {
            Write-Host "  $($script:ICON_LIST) Event Logs: $(Format-ByteSize -Bytes $size)"
            Write-Host "    $($script:GRAY)Clear via Event Viewer or: wevtutil cl <logname>$($script:NC)"
        }
    }

    Stop-MoleSection
}

# ============================================================================
# DirectX Shader Cache
# ============================================================================

function Clear-ShaderCache {
    <#
    .SYNOPSIS
        Cleans DirectX shader cache (can grow large for gamers).
    #>
    Start-MoleSection -Title "DirectX Shader Cache"

    $shaderCache = Join-Path $env:LOCALAPPDATA "D3DSCache"
    if (Test-Path $shaderCache) {
        Invoke-SafeClean -Path "$shaderCache\*" -Description "DirectX shader cache"
    }

    # NVIDIA shader cache
    $nvidiaCache = Join-Path $env:LOCALAPPDATA "NVIDIA\DXCache"
    if (Test-Path $nvidiaCache) {
        Invoke-SafeClean -Path "$nvidiaCache\*" -Description "NVIDIA DirectX cache"
    }

    $nvidiaGLCache = Join-Path $env:LOCALAPPDATA "NVIDIA\GLCache"
    if (Test-Path $nvidiaGLCache) {
        Invoke-SafeClean -Path "$nvidiaGLCache\*" -Description "NVIDIA OpenGL cache"
    }

    # AMD shader cache
    $amdCache = Join-Path $env:LOCALAPPDATA "AMD\DxCache"
    if (Test-Path $amdCache) {
        Invoke-SafeClean -Path "$amdCache\*" -Description "AMD DirectX cache"
    }

    $amdGLCache = Join-Path $env:LOCALAPPDATA "AMD\GLCache"
    if (Test-Path $amdGLCache) {
        Invoke-SafeClean -Path "$amdGLCache\*" -Description "AMD OpenGL cache"
    }

    # Intel shader cache
    $intelCache = Join-Path $env:LOCALAPPDATA "Intel\ShaderCache"
    if (Test-Path $intelCache) {
        Invoke-SafeClean -Path "$intelCache\*" -Description "Intel shader cache"
    }

    Stop-MoleSection
}

# ============================================================================
# Gaming Platform Caches
# ============================================================================

function Clear-GamingCaches {
    <#
    .SYNOPSIS
        Cleans Steam, Epic Games, and other gaming platform caches.
    #>
    Start-MoleSection -Title "Gaming Platform Caches"

    # Steam
    $steamPath = "C:\Program Files (x86)\Steam"
    if (Test-Path $steamPath) {
        # Steam download cache
        $steamDownloads = Join-Path $steamPath "steamapps\downloading"
        if (Test-Path $steamDownloads) {
            $size = Get-PathSize -Path $steamDownloads
            if ($size -gt 100MB) {
                Write-Host "  $($script:ICON_LIST) Steam downloads in progress: $(Format-ByteSize -Bytes $size)"
            }
        }

        # Steam shader cache
        $steamShaders = Join-Path $steamPath "steamapps\shadercache"
        if (Test-Path $steamShaders) {
            Invoke-SafeClean -Path "$steamShaders\*" -Description "Steam shader cache"
        }

        # Steam HTML cache
        $steamHtmlCache = Join-Path $env:LOCALAPPDATA "Steam\htmlcache"
        if (Test-Path $steamHtmlCache) {
            Invoke-SafeClean -Path "$steamHtmlCache\*" -Description "Steam browser cache"
        }
    }

    # Epic Games
    $epicCache = Join-Path $env:LOCALAPPDATA "EpicGamesLauncher\Saved"
    if (Test-Path $epicCache) {
        $webcache = Join-Path $epicCache "webcache"
        if (Test-Path $webcache) {
            Invoke-SafeClean -Path "$webcache\*" -Description "Epic Games web cache"
        }
    }

    # GOG Galaxy
    $gogCache = Join-Path $env:LOCALAPPDATA "GOG.com\Galaxy\webcache"
    if (Test-Path $gogCache) {
        Invoke-SafeClean -Path "$gogCache\*" -Description "GOG Galaxy cache"
    }

    # Origin / EA App
    $originCache = Join-Path $env:LOCALAPPDATA "Origin\ThinSetup"
    if (Test-Path $originCache) {
        Invoke-SafeClean -Path "$originCache\*" -Description "Origin setup cache"
    }

    $eaCache = Join-Path $env:LOCALAPPDATA "EADesktop\cache"
    if (Test-Path $eaCache) {
        Invoke-SafeClean -Path "$eaCache\*" -Description "EA Desktop cache"
    }

    Stop-MoleSection
}

# ============================================================================
# Communication Apps Caches
# ============================================================================

function Clear-CommunicationAppCaches {
    <#
    .SYNOPSIS
        Cleans Discord, Slack, Teams, Zoom, and other communication app caches.
    #>
    Start-MoleSection -Title "Communication App Caches"

    # Discord
    $discordCache = Join-Path $env:APPDATA "discord\Cache"
    if (Test-Path $discordCache) {
        Invoke-SafeClean -Path "$discordCache\*" -Description "Discord cache"
    }
    $discordCodeCache = Join-Path $env:APPDATA "discord\Code Cache"
    if (Test-Path $discordCodeCache) {
        Invoke-SafeClean -Path "$discordCodeCache\*" -Description "Discord code cache"
    }
    $discordGPUCache = Join-Path $env:APPDATA "discord\GPUCache"
    if (Test-Path $discordGPUCache) {
        Invoke-SafeClean -Path "$discordGPUCache\*" -Description "Discord GPU cache"
    }

    # Slack
    $slackCache = Join-Path $env:APPDATA "Slack\Cache"
    if (Test-Path $slackCache) {
        Invoke-SafeClean -Path "$slackCache\*" -Description "Slack cache"
    }
    $slackServiceWorker = Join-Path $env:APPDATA "Slack\Service Worker\CacheStorage"
    if (Test-Path $slackServiceWorker) {
        Invoke-SafeClean -Path "$slackServiceWorker\*" -Description "Slack service worker cache"
    }

    # Microsoft Teams (new)
    $teamsCache = Join-Path $env:LOCALAPPDATA "Packages\MSTeams_*\LocalCache"
    $teamsCaches = Get-ChildItem -Path (Split-Path $teamsCache) -Filter "MSTeams_*" -Directory -ErrorAction SilentlyContinue
    foreach ($t in $teamsCaches) {
        $cache = Join-Path $t.FullName "LocalCache\Microsoft\MSTeams"
        if (Test-Path $cache) {
            Invoke-SafeClean -Path "$cache\EBWebView\*" -Description "Teams WebView cache"
        }
    }

    # Microsoft Teams (classic)
    $teamsClassic = Join-Path $env:APPDATA "Microsoft\Teams"
    if (Test-Path $teamsClassic) {
        Invoke-SafeClean -Path "$teamsClassic\Cache\*" -Description "Teams classic cache"
        Invoke-SafeClean -Path "$teamsClassic\Service Worker\CacheStorage\*" -Description "Teams service worker"
        Invoke-SafeClean -Path "$teamsClassic\Code Cache\*" -Description "Teams code cache"
    }

    # Zoom
    $zoomCache = Join-Path $env:APPDATA "Zoom\data"
    if (Test-Path $zoomCache) {
        Invoke-SafeClean -Path "$zoomCache\*.log" -Description "Zoom logs"
    }

    # Telegram
    $telegramCache = Join-Path $env:APPDATA "Telegram Desktop\tdata\user_data"
    if (Test-Path $telegramCache) {
        $size = Get-PathSize -Path $telegramCache
        if ($size -gt 500MB) {
            Write-Host "  $($script:ICON_LIST) Telegram cache: $(Format-ByteSize -Bytes $size)"
            Write-Host "    $($script:GRAY)Clear via Telegram settings$($script:NC)"
        }
    }

    # WhatsApp
    $whatsappCache = Join-Path $env:LOCALAPPDATA "WhatsApp\Cache"
    if (Test-Path $whatsappCache) {
        Invoke-SafeClean -Path "$whatsappCache\*" -Description "WhatsApp cache"
    }

    Stop-MoleSection
}

# ============================================================================
# Media App Caches
# ============================================================================

function Clear-MediaAppCaches {
    <#
    .SYNOPSIS
        Cleans Spotify, VLC, and other media app caches.
    #>
    Start-MoleSection -Title "Media App Caches"

    # Spotify (can be several GB)
    $spotifyCache = Join-Path $env:LOCALAPPDATA "Spotify\Storage"
    if (Test-Path $spotifyCache) {
        $size = Get-PathSize -Path $spotifyCache
        if ($size -gt 500MB) {
            Write-Host "  $($script:ICON_LIST) Spotify cache: $($script:YELLOW)$(Format-ByteSize -Bytes $size)$($script:NC)"
            Write-Host "    $($script:GRAY)Clear via Spotify settings or delete Storage folder$($script:NC)"
        }
    }

    $spotifyData = Join-Path $env:LOCALAPPDATA "Spotify\Data"
    if (Test-Path $spotifyData) {
        Invoke-SafeClean -Path "$spotifyData\*" -Description "Spotify data cache"
    }

    # VLC
    $vlcCache = Join-Path $env:APPDATA "vlc\art"
    if (Test-Path $vlcCache) {
        Invoke-SafeClean -Path "$vlcCache\*" -Description "VLC art cache"
    }

    # Windows Media Player
    $wmpCache = Join-Path $env:LOCALAPPDATA "Microsoft\Media Player"
    if (Test-Path $wmpCache) {
        Invoke-SafeClean -Path "$wmpCache\Art Cache\*" -Description "WMP art cache"
        Invoke-SafeClean -Path "$wmpCache\Transcoded Files Cache\*" -Description "WMP transcoded cache"
    }

    Stop-MoleSection
}

# ============================================================================
# Windows Subsystem for Linux (WSL)
# ============================================================================

function Get-WSLStatus {
    <#
    .SYNOPSIS
        Reports WSL distribution sizes.
    #>
    Start-MoleSection -Title "Windows Subsystem for Linux"

    $wslPath = Join-Path $env:LOCALAPPDATA "Packages"
    $wslDistros = Get-ChildItem -Path $wslPath -Filter "*WSL*" -Directory -ErrorAction SilentlyContinue

    $totalSize = 0
    foreach ($distro in $wslDistros) {
        $localState = Join-Path $distro.FullName "LocalState"
        if (Test-Path $localState) {
            $size = Get-PathSize -Path $localState
            $totalSize += $size
            if ($size -gt 1GB) {
                $name = $distro.Name -replace 'CanonicalGroupLimited\.|TheDebianProject\.|KaliLinux\.|.Ubuntu.*|.Debian.*|_.*', ''
                Write-Host "  $($script:ICON_LIST) $name`: $(Format-ByteSize -Bytes $size)"
            }
        }
    }

    if ($totalSize -gt 0) {
        Write-Host "    $($script:GRAY)Compact with: wsl --shutdown && Optimize-VHD$($script:NC)"
    }

    Stop-MoleSection
}

# ============================================================================
# Windows Search Index
# ============================================================================

function Clear-WindowsSearchIndex {
    <#
    .SYNOPSIS
        Reports Windows Search index size.
    #>
    Start-MoleSection -Title "Windows Search Index"

    $searchPath = Join-Path $env:ProgramData "Microsoft\Search\Data\Applications\Windows"
    try {
        if (Test-Path $searchPath -ErrorAction SilentlyContinue) {
            $size = Get-PathSize -Path $searchPath
            if ($size -gt 1GB) {
                Write-Host "  $($script:ICON_LIST) Search index: $(Format-ByteSize -Bytes $size)"
                Write-Host "    $($script:GRAY)Rebuild via Indexing Options in Control Panel$($script:NC)"
            }
        }
    }
    catch {
        # Access denied - need admin
        if (Test-IsElevated) {
            Write-MoleDebug "Could not access search index: $($_.Exception.Message)"
        }
    }

    Stop-MoleSection
}

# ============================================================================
# OneDrive Cache
# ============================================================================

function Clear-OneDriveCache {
    <#
    .SYNOPSIS
        Cleans OneDrive local cache files.
    #>
    Start-MoleSection -Title "OneDrive Cache"

    $oneDriveCache = Join-Path $env:LOCALAPPDATA "Microsoft\OneDrive\logs"
    if (Test-Path $oneDriveCache) {
        Invoke-SafeClean -Path "$oneDriveCache\*" -Description "OneDrive logs"
    }

    # OneDrive setup files
    $oneDriveSetup = Join-Path $env:LOCALAPPDATA "Microsoft\OneDrive\setup\logs"
    if (Test-Path $oneDriveSetup) {
        Invoke-SafeClean -Path "$oneDriveSetup\*" -Description "OneDrive setup logs"
    }

    Stop-MoleSection
}

# ============================================================================
# Downloaded Program Files (ActiveX/Java)
# ============================================================================

function Clear-DownloadedProgramFiles {
    <#
    .SYNOPSIS
        Cleans downloaded program files (ActiveX, Java applets).
    #>
    Start-MoleSection -Title "Downloaded Program Files"

    if (-not (Test-IsElevated)) {
        Stop-MoleSection
        return
    }

    $dpf = Join-Path $env:SystemRoot "Downloaded Program Files"
    if (Test-Path $dpf) {
        $items = Get-ChildItem -Path $dpf -Force -ErrorAction SilentlyContinue
        if ($items.Count -gt 0) {
            $size = Get-PathSize -Path $dpf
            Invoke-SafeClean -Path "$dpf\*" -Description "Downloaded program files"
        }
    }

    Stop-MoleSection
}

# ============================================================================
# Master Windows Cleanup Function
# ============================================================================

function Invoke-WindowsCleanup {
    <#
    .SYNOPSIS
        Performs all Windows-specific cleanup operations.
    .PARAMETER IncludeAdminTasks
        Include tasks that require admin privileges.
    .OUTPUTS
        Hashtable with total CleanedSize and AdminTasksSkipped count.
    #>
    param(
        [bool]$IncludeAdminTasks = $true
    )

    Write-MoleInfo "Starting Windows-specific cleanup..."

    $isAdmin = Test-IsElevated
    $adminSkipped = 0

    # Tasks that don't require admin
    Clear-DnsCache
    Clear-WindowsErrorReports
    Clear-WindowsStoreCache
    Clear-IECache
    Clear-ShaderCache
    Clear-GamingCaches
    Clear-CommunicationAppCaches
    Clear-MediaAppCaches
    Clear-OneDriveCache

    # Report large items (info only)
    Clear-WindowsOld
    Get-HibernationStatus
    Get-WSLStatus
    Clear-WindowsSearchIndex

    # Tasks that require admin
    if ($IncludeAdminTasks) {
        if ($isAdmin) {
            Clear-WindowsUpdateCache
            Clear-SystemTemp
            Clear-PrefetchFiles
            Clear-MemoryDumps
            Clear-DeliveryOptimization
            Clear-SystemFontCache
            Clear-WindowsInstallerCache
            Clear-EventLogs
            Clear-DownloadedProgramFiles
        }
        else {
            Write-Host ""
            Write-Host "$($script:YELLOW)Some cleanup tasks were skipped (require administrator)$($script:NC)"
            Write-Host "$($script:GRAY)Run 'mole clean --admin' for full cleanup$($script:NC)"
            $adminSkipped = 9  # Number of admin tasks skipped
        }
    }

    return @{
        CleanedSize = 0
        AdminTasksSkipped = $adminSkipped
    }
}

# ============================================================================
# Export Module Members
# ============================================================================
Export-ModuleMember -Function @(
    'Clear-WindowsUpdateCache'
    'Clear-SystemTemp'
    'Clear-WindowsErrorReports'
    'Clear-DnsCache'
    'Clear-PrefetchFiles'
    'Clear-MemoryDumps'
    'Clear-DeliveryOptimization'
    'Clear-WindowsInstallerCache'
    'Clear-SystemFontCache'
    'Clear-WindowsStoreCache'
    'Clear-IECache'
    'Clear-WindowsOld'
    'Get-HibernationStatus'
    'Clear-EventLogs'
    'Clear-ShaderCache'
    'Clear-GamingCaches'
    'Clear-CommunicationAppCaches'
    'Clear-MediaAppCaches'
    'Get-WSLStatus'
    'Clear-WindowsSearchIndex'
    'Clear-OneDriveCache'
    'Clear-DownloadedProgramFiles'
    'Invoke-WindowsCleanup'
)
