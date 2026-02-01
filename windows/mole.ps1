#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Mole - Windows System Cleaner
.DESCRIPTION
    A safe and thorough system cleaner for Windows.
    Cleans temp files, browser caches, developer tool caches, and more.
.PARAMETER Command
    The command to run: clean, analyze, status, whitelist, purge, optimize, help, version
.PARAMETER DryRun
    Preview what would be cleaned without deleting anything.
.PARAMETER Quick
    Quick cleanup mode - only essential items.
.PARAMETER Select
    Interactive selection of items to clean.
.PARAMETER Admin
    Request admin privileges for full cleanup.
.PARAMETER DebugMode
    Enable debug logging.
.EXAMPLE
    .\mole.ps1 clean
    Performs a full system cleanup.
.EXAMPLE
    .\mole.ps1 clean --dry-run
    Preview cleanup without deleting files.
.EXAMPLE
    .\mole.ps1 clean --quick
    Quick cleanup of essential items only.
.EXAMPLE
    .\mole.ps1 whitelist
    Open the whitelist manager.
.NOTES
    Author: Mole Project
    License: MIT
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet("clean", "analyze", "status", "whitelist", "purge", "optimize", "media", "help", "version", "")]
    [string]$Command = "",

    [Alias("n")]
    [switch]$DryRun,

    [Alias("q")]
    [switch]$Quick,

    [Alias("s")]
    [switch]$Select,

    [switch]$Admin,

    [Alias("d")]
    [switch]$DebugMode,

    [switch]$Yes,

    [switch]$NoBrowser,

    [switch]$NoDev,

    [switch]$NoRecycleBin,

    [ValidatePattern("^[A-Za-z]$")]
    [string]$Drive = "C",

    [Parameter(ValueFromRemainingArguments)]
    [string[]]$RemainingArgs
)

# Script root
$script:MOLE_ROOT = $PSScriptRoot

# Set debug mode
if ($DebugMode) {
    $env:MOLE_DEBUG = "1"
}

# Import modules
$modulePaths = @(
    (Join-Path $MOLE_ROOT "lib\core\Base.psm1"),
    (Join-Path $MOLE_ROOT "lib\core\Log.psm1"),
    (Join-Path $MOLE_ROOT "lib\core\FileOps.psm1"),
    (Join-Path $MOLE_ROOT "lib\core\PathProtection.psm1"),
    (Join-Path $MOLE_ROOT "lib\core\Elevation.psm1"),
    (Join-Path $MOLE_ROOT "lib\core\UI.psm1"),
    (Join-Path $MOLE_ROOT "lib\clean\User.psm1"),
    (Join-Path $MOLE_ROOT "lib\clean\Browsers.psm1"),
    (Join-Path $MOLE_ROOT "lib\clean\Dev.psm1"),
    (Join-Path $MOLE_ROOT "lib\clean\Windows.psm1"),
    (Join-Path $MOLE_ROOT "lib\clean\System.psm1"),
    (Join-Path $MOLE_ROOT "lib\manage\Whitelist.psm1")
)

foreach ($modulePath in $modulePaths) {
    if (Test-Path $modulePath) {
        Import-Module $modulePath -Force -DisableNameChecking -Scope Global -ErrorAction SilentlyContinue
    }
}

# ============================================================================
# Color Constants (for script scope access)
# ============================================================================
$script:ESC = [char]27
$script:GREEN = "$($script:ESC)[0;32m"
$script:BLUE = "$($script:ESC)[0;34m"
$script:CYAN = "$($script:ESC)[0;36m"
$script:YELLOW = "$($script:ESC)[0;33m"
$script:PURPLE = "$($script:ESC)[0;35m"
$script:PURPLE_BOLD = "$($script:ESC)[1;35m"
$script:GRAY = "$($script:ESC)[0;90m"
$script:NC = "$($script:ESC)[0m"
$script:ICON_SUCCESS = [char]0x2713
$script:ICON_ERROR = [char]0x263B
$script:ICON_ARROW = [char]0x27A4
$script:ICON_LIST = [char]0x2022

# ============================================================================
# Helper Functions (for script scope)
# ============================================================================
function Write-MoleBanner {
    $banner = @"
$($script:PURPLE_BOLD)
    __  ___      __
   /  |/  /___  / /__
  / /|_/ / __ \/ / _ \
 / /  / / /_/ / /  __/
/_/  /_/\____/_/\___/
$($script:NC)
"@
    Write-Host $banner
    Write-Host "$($script:GRAY)Windows System Cleaner$($script:NC)"
}

function Format-Size([long]$Bytes) {
    if ($Bytes -ge 1GB) { return "{0:N2}GB" -f ($Bytes / 1GB) }
    elseif ($Bytes -ge 1MB) { return "{0:N1}MB" -f ($Bytes / 1MB) }
    elseif ($Bytes -ge 1KB) { return "{0:N0}KB" -f ($Bytes / 1KB) }
    else { return "{0}B" -f $Bytes }
}

function Get-DirSize([string]$Path) {
    if (-not (Test-Path $Path)) { return 0 }
    try {
        $size = (Get-ChildItem $Path -Recurse -Force -ErrorAction SilentlyContinue |
                 Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        return [long]$(if ($null -eq $size) { 0 } else { $size })
    }
    catch { return 0 }
}

# ============================================================================
# Version Information
# ============================================================================
$script:MOLE_VERSION = "1.0.0-windows"

function Show-Version {
    Write-Host "Mole $script:MOLE_VERSION"
    Write-Host "Windows System Cleaner"
    Write-Host ""
    Write-Host "PowerShell $($PSVersionTable.PSVersion)"

    # Get Windows version info directly (avoiding module scope issues)
    $version = [System.Environment]::OSVersion.Version
    $displayVersion = try {
        (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name DisplayVersion -ErrorAction Stop).DisplayVersion
    } catch { "Unknown" }
    Write-Host "Windows $displayVersion (Build $($version.Build))"
}

# ============================================================================
# Help
# ============================================================================
function Show-Help {
    $banner = @"
$($script:PURPLE_BOLD)
    __  ___      __
   /  |/  /___  / /__
  / /|_/ / __ \/ / _ \
 / /  / / /_/ / /  __/
/_/  /_/\____/_/\___/
$($script:NC)
Mole - Windows System Cleaner
Version $script:MOLE_VERSION

USAGE:
    mole <command> [options]

COMMANDS:
    clean           Clean system caches and temp files
    analyze         Analyze disk usage (requires Go TUI)
    status          Show system status (requires Go TUI)
    whitelist       Manage protected paths
    purge           Clean project build artifacts
    optimize        Optimize system (cache rebuild, service refresh)
    media           Find and transfer media files between drives
    help            Show this help message
    version         Show version information

CLEAN OPTIONS:
    -DryRun, -n     Preview what would be cleaned
    -Quick, -q      Quick cleanup (temp, browser, recycle bin only)
    -Select, -s     Interactive selection of items to clean
    -Admin          Request admin privileges for full cleanup
    -Yes            Skip confirmation prompts
    -NoBrowser      Skip browser cache cleanup
    -NoDev          Skip developer tools cleanup
    -NoRecycleBin   Skip Recycle Bin cleanup
    -Drive X        Show free space for drive X (default: C)

MEDIA OPTIONS:
    mole media scan C:          Scan C: drive for media files
    mole media transfer C: E:   Transfer media from C: to E:
    mole media transfer C: E: -n  Preview transfer (dry-run)

GLOBAL OPTIONS:
    -DebugMode, -d  Enable debug logging

EXAMPLES:
    mole clean                  Full cleanup with confirmation
    mole clean -n               Preview without deleting (dry-run)
    mole clean -q               Quick essential cleanup
    mole clean -Admin           Full cleanup with admin rights
    mole clean -Drive C         Show C: drive free space
    mole whitelist              Manage whitelist interactively
    mole media scan C:          Find all videos/images on C:
    mole media transfer C: E:   Move media from C: to E:

CONFIGURATION:
    Config directory: $env:LOCALAPPDATA\mole
    Whitelist file:   $env:LOCALAPPDATA\mole\whitelist
    Log file:         $env:LOCALAPPDATA\mole\mole.log

"@
    Write-Host $banner
}

# ============================================================================
# Clean Command
# ============================================================================
function Invoke-CleanCommand {
    # Initialize whitelist
    Initialize-Whitelist

    # Handle admin elevation
    if ($Admin -and -not (Test-IsElevated)) {
        Write-MoleInfo "Requesting administrator privileges..."

        $scriptPath = $MyInvocation.PSCommandPath
        if (-not $scriptPath) {
            $scriptPath = $PSCommandPath
        }

        $argList = @("clean")
        if ($DryRun) { $argList += "-DryRun" }
        if ($Quick) { $argList += "-Quick" }
        if ($Yes) { $argList += "-Yes" }
        if ($NoBrowser) { $argList += "-NoBrowser" }
        if ($NoDev) { $argList += "-NoDev" }
        if ($NoRecycleBin) { $argList += "-NoRecycleBin" }
        if ($DebugMode) { $argList += "-DebugMode" }
        if ($Drive) { $argList += "-Drive"; $argList += $Drive }

        try {
            Start-Process -FilePath "powershell.exe" `
                -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$scriptPath`"", $argList `
                -Verb RunAs `
                -Wait
        }
        catch {
            Write-MoleWarning "Administrator access was declined or failed"
        }

        return
    }

    # Run appropriate cleanup (suppress return value output)
    if ($Quick) {
        Invoke-QuickCleanup -DryRun:$DryRun -Drive $Drive | Out-Null
    }
    elseif ($Select) {
        Invoke-SelectiveCleanup -DryRun:$DryRun -Drive $Drive | Out-Null
    }
    else {
        Invoke-FullCleanup `
            -DryRun:$DryRun `
            -IncludeBrowsers:(-not $NoBrowser) `
            -IncludeDevTools:(-not $NoDev) `
            -IncludeRecycleBin:(-not $NoRecycleBin) `
            -SkipConfirmation:$Yes `
            -Drive $Drive | Out-Null
    }
}

# ============================================================================
# Whitelist Command
# ============================================================================
function Invoke-WhitelistCommand {
    $subCommand = if ($RemainingArgs.Count -gt 0) { $RemainingArgs[0] } else { "" }

    switch ($subCommand) {
        "show" {
            Show-Whitelist
        }
        "reset" {
            Reset-Whitelist
        }
        "add" {
            if ($RemainingArgs.Count -gt 1) {
                Add-WhitelistPattern -Pattern $RemainingArgs[1]
            }
            else {
                Write-MoleError "Usage: mole whitelist add <pattern>"
            }
        }
        "remove" {
            if ($RemainingArgs.Count -gt 1) {
                Remove-WhitelistPattern -Pattern $RemainingArgs[1]
            }
            else {
                Write-MoleError "Usage: mole whitelist remove <pattern>"
            }
        }
        default {
            Show-WhitelistManager
        }
    }
}

# ============================================================================
# Analyze Command
# ============================================================================
function Invoke-AnalyzeCommand {
    # Check for Go binary
    $analyzeExe = Join-Path $MOLE_ROOT "bin\analyze.exe"

    if (Test-Path $analyzeExe) {
        & $analyzeExe $RemainingArgs
    }
    else {
        Write-Host "Disk analyzer not found." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Run these commands to build the analyzer:"
        Write-Host "  cd $(Split-Path $MOLE_ROOT -Parent)" -ForegroundColor DarkGray
        Write-Host "  `$env:GOOS='windows'; `$env:GOARCH='amd64'" -ForegroundColor DarkGray
        Write-Host "  go build -o windows/bin/analyze.exe ./cmd/analyze" -ForegroundColor DarkGray
        Write-Host ""

        # Fallback to simple disk info
        Write-Host "Current disk space:"
        Get-PSDrive -PSProvider FileSystem |
            Where-Object { $_.Used -gt 0 } |
            ForEach-Object {
                $total = $_.Used + $_.Free
                $usedPct = if ($total -gt 0) { [int](($_.Used / $total) * 100) } else { 0 }
                [PSCustomObject]@{
                    Drive = $_.Name
                    Used = "{0:N2} GB" -f ($_.Used / 1GB)
                    Free = "{0:N2} GB" -f ($_.Free / 1GB)
                    Total = "{0:N2} GB" -f ($total / 1GB)
                    "Used%" = "$usedPct%"
                }
            } | Format-Table -AutoSize
    }
}

# ============================================================================
# Status Command
# ============================================================================
function Invoke-StatusCommand {
    # Check for Go binary
    $statusExe = Join-Path $MOLE_ROOT "bin\status.exe"

    if (Test-Path $statusExe) {
        & $statusExe $RemainingArgs
    }
    else {
        Write-Host "Status dashboard not found. Showing basic info..." -ForegroundColor Yellow
        Write-Host ""

        # Get system info inline
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        $os = Get-CimInstance Win32_OperatingSystem
        $displayVersion = try {
            (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name DisplayVersion -ErrorAction Stop).DisplayVersion
        } catch { "Unknown" }

        Write-Host "System Status" -ForegroundColor Magenta
        Write-Host ("-" * 50) -ForegroundColor DarkGray

        Write-Host ("  {0,-15} {1}" -f "Computer:", $env:COMPUTERNAME)
        Write-Host ("  {0,-15} {1}" -f "User:", $env:USERNAME)
        Write-Host ("  {0,-15} {1}" -f "OS:", "$($os.Caption) ($displayVersion)")
        Write-Host ("  {0,-15} {1}" -f "Architecture:", $(if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }))
        Write-Host ("  {0,-15} {1}" -f "Processors:", [Environment]::ProcessorCount)
        Write-Host ("  {0,-15} {1}" -f "Admin:", $(if ($isAdmin) { "Yes" } else { "No" }))

        Write-Host ""
        Write-Host "Disk Space" -ForegroundColor Magenta
        Write-Host ("-" * 50) -ForegroundColor DarkGray

        Get-PSDrive -PSProvider FileSystem |
            Where-Object { $_.Used -gt 0 } |
            ForEach-Object {
                $total = $_.Used + $_.Free
                $usedPct = if ($total -gt 0) { [int](($_.Used / $total) * 100) } else { 0 }
                $freeGB = "{0:N2} GB" -f ($_.Free / 1GB)
                $totalGB = "{0:N2} GB" -f ($total / 1GB)
                Write-Host ("  {0,-15} {1} free of {2} ({3}% used)" -f "Drive $($_.Name):", $freeGB, $totalGB, $usedPct)
            }

        Write-Host ""
        Write-Host "Run 'mole clean --dry-run' to see cleanup opportunities" -ForegroundColor DarkGray
    }
}

# ============================================================================
# Purge Command
# ============================================================================
function Invoke-PurgeCommand {
    Write-MoleBanner

    Write-Host "$($script:PURPLE_BOLD)Project Artifact Cleanup$($script:NC)"
    Write-Host "$($script:GRAY)Cleans build artifacts from project directories$($script:NC)"
    Write-Host ""

    $targetDir = if ($RemainingArgs.Count -gt 0) { $RemainingArgs[0] } else { Get-Location }

    if (-not (Test-Path $targetDir)) {
        Write-Host "$($script:ICON_ERROR) Directory not found: $targetDir" -ForegroundColor Yellow
        return
    }

    Write-Host "Scanning: $targetDir"
    Write-Host ""

    # Common build artifact directories
    $artifactPatterns = @(
        "node_modules",
        ".next",
        ".nuxt",
        "dist",
        "build",
        "target",           # Rust/Java
        "bin\Debug",        # .NET
        "bin\Release",      # .NET
        "obj",              # .NET
        "__pycache__",
        ".pytest_cache",
        ".mypy_cache",
        "*.pyc",
        ".tox",
        ".eggs",
        "*.egg-info",
        ".gradle",
        ".idea",            # JetBrains (optional)
        ".vscode",          # VS Code (optional)
        "coverage",
        ".nyc_output",
        ".parcel-cache",
        ".turbo",
        ".vite"
    )

    $found = @()

    foreach ($pattern in $artifactPatterns) {
        $matches = Get-ChildItem -Path $targetDir -Filter $pattern -Recurse -Directory -ErrorAction SilentlyContinue
        foreach ($match in $matches) {
            $size = Get-DirSize -Path $match.FullName
            if ($size -gt 0) {
                $found += @{
                    Path = $match.FullName
                    Size = $size
                    Name = $match.Name
                }
            }
        }
    }

    if ($found.Count -eq 0) {
        Write-Host "No build artifacts found."
        return
    }

    $totalSize = ($found | Measure-Object -Property Size -Sum).Sum

    Write-Host "Found $($found.Count) artifact directories ($(Format-Size $totalSize)):"
    Write-Host ""

    foreach ($item in ($found | Sort-Object Size -Descending | Select-Object -First 20)) {
        $relativePath = $item.Path.Replace($targetDir, ".")
        Write-Host "  $($script:ICON_LIST) $relativePath ($($script:GREEN)$(Format-Size $item.Size)$($script:NC))"
    }

    if ($found.Count -gt 20) {
        Write-Host "  $($script:GRAY)... and $($found.Count - 20) more$($script:NC)"
    }

    Write-Host ""

    if ($DryRun) {
        Write-Host "$($script:YELLOW)DRY RUN: Would remove $(Format-Size $totalSize)$($script:NC)"
        return
    }

    # Simple confirmation prompt
    $response = Read-Host "Remove these directories? [y/N]"
    if ($response -ne 'y' -and $response -ne 'Y') {
        Write-Host "Cancelled."
        return
    }

    $cleaned = 0
    foreach ($item in $found) {
        try {
            Remove-Item -Path $item.Path -Recurse -Force -ErrorAction Stop
            $cleaned++
        }
        catch { }
    }

    Write-Host ""
    Write-Host "  $($script:GREEN)$($script:ICON_SUCCESS)$($script:NC) Removed $cleaned directories ($(Format-Size $totalSize))"
}

# ============================================================================
# Optimize Command
# ============================================================================
function Invoke-OptimizeCommand {
    Write-MoleBanner

    Write-Host "$($script:PURPLE_BOLD)System Optimization$($script:NC)"
    Write-Host "$($script:GRAY)Rebuilds caches and refreshes services$($script:NC)"
    Write-Host ""

    # Check for admin
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    # DNS cache flush
    Write-Host "$($script:ICON_ARROW) Flushing DNS cache..."
    if (-not $DryRun) {
        ipconfig /flushdns | Out-Null
        Write-Host "  $($script:GREEN)$($script:ICON_SUCCESS)$($script:NC) DNS cache flushed"
    }
    else {
        Write-Host "  $($script:YELLOW)->$($script:NC) Would flush DNS cache"
    }

    # Icon cache rebuild (if requested)
    if ($Admin -or $isAdmin) {
        Write-Host "$($script:ICON_ARROW) Rebuilding icon cache..."

        # Stop Explorer
        if (-not $DryRun) {
            $explorerProc = Get-Process -Name explorer -ErrorAction SilentlyContinue
            if ($explorerProc) {
                # Kill explorer and let it restart
                Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 2

                # Delete icon cache
                $iconCachePath = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\iconcache*.db"
                Remove-Item -Path $iconCachePath -Force -ErrorAction SilentlyContinue

                # Explorer will restart automatically
                Start-Sleep -Seconds 2

                Write-Host "  $($script:GREEN)$($script:ICON_SUCCESS)$($script:NC) Icon cache rebuilt"
            }
        }
        else {
            Write-Host "  $($script:YELLOW)->$($script:NC) Would rebuild icon cache"
        }
    }

    # Windows Store cache reset
    Write-Host "$($script:ICON_ARROW) Resetting Windows Store cache..."
    if (-not $DryRun) {
        $wsPath = Join-Path $env:LOCALAPPDATA "Packages\*Store*\LocalCache"
        $stores = Get-ChildItem -Path $wsPath -ErrorAction SilentlyContinue
        foreach ($store in $stores) {
            Remove-Item -Path "$($store.FullName)\*" -Recurse -Force -ErrorAction SilentlyContinue
        }
        Write-Host "  $($script:GREEN)$($script:ICON_SUCCESS)$($script:NC) Windows Store cache reset"
    }
    else {
        Write-Host "  $($script:YELLOW)->$($script:NC) Would reset Windows Store cache"
    }

    Write-Host ""
    Write-Host ("-" * 50) -ForegroundColor DarkGray
    Write-Host "Optimization complete"
}

# ============================================================================
# Media Command - Find and Transfer Media Files
# ============================================================================
function Invoke-MediaCommand {
    Write-MoleBanner

    # Media file extensions
    $imageExtensions = @('.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.heic', '.heif',
                         '.tiff', '.tif', '.raw', '.cr2', '.nef', '.arw', '.dng', '.svg', '.ico')
    $videoExtensions = @('.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv', '.webm', '.m4v',
                         '.mpeg', '.mpg', '.3gp', '.ts', '.mts', '.m2ts', '.vob')
    $allMediaExtensions = $imageExtensions + $videoExtensions

    # Parse subcommand
    $subCommand = if ($RemainingArgs.Count -gt 0) { $RemainingArgs[0] } else { "" }

    switch ($subCommand) {
        "scan" {
            # Scan drive for media files
            $sourceDrive = if ($RemainingArgs.Count -gt 1) { $RemainingArgs[1].TrimEnd(':') } else { "C" }
            $sourcePath = "${sourceDrive}:\"

            if (-not (Test-Path $sourcePath)) {
                Write-MoleError "Drive $sourceDrive`: does not exist"
                return
            }

            Write-Host "$($script:PURPLE_BOLD)Media Scanner$($script:NC)"
            Write-Host "Scanning $($script:CYAN)$sourceDrive`:$($script:NC) for images and videos..."
            Write-Host ""

            # Directories to skip
            $skipDirs = @('Windows', 'Program Files', 'Program Files (x86)', '$Recycle.Bin',
                          'System Volume Information', 'ProgramData', 'Recovery', 'PerfLogs')

            $mediaFiles = @{
                Images = @()
                Videos = @()
            }
            $totalSize = @{ Images = 0; Videos = 0 }
            $scannedDirs = 0

            # Get top-level directories
            $topDirs = Get-ChildItem -Path $sourcePath -Directory -Force -ErrorAction SilentlyContinue |
                Where-Object { $skipDirs -notcontains $_.Name }

            Write-Host "  Scanning directories..." -NoNewline

            foreach ($topDir in $topDirs) {
                $scannedDirs++
                Write-Host "`r  Scanning: $($topDir.Name.PadRight(40))" -NoNewline

                try {
                    $files = Get-ChildItem -Path $topDir.FullName -Recurse -File -Force -ErrorAction SilentlyContinue |
                        Where-Object { $allMediaExtensions -contains $_.Extension.ToLower() }

                    foreach ($file in $files) {
                        $ext = $file.Extension.ToLower()
                        if ($imageExtensions -contains $ext) {
                            $mediaFiles.Images += $file
                            $totalSize.Images += $file.Length
                        }
                        elseif ($videoExtensions -contains $ext) {
                            $mediaFiles.Videos += $file
                            $totalSize.Videos += $file.Length
                        }
                    }
                }
                catch {
                    # Skip inaccessible directories
                }
            }

            Write-Host "`r" + (" " * 60) + "`r"  # Clear line
            Write-Host ""
            Write-Host "$($script:PURPLE_BOLD)Scan Results$($script:NC)"
            Write-Host ("-" * 50)
            Write-Host ""
            Write-Host "  $($script:ICON_SUCCESS) Images: $($script:GREEN)$($mediaFiles.Images.Count)$($script:NC) files ($($script:CYAN)$(Format-ByteSize -Bytes $totalSize.Images)$($script:NC))"
            Write-Host "  $($script:ICON_SUCCESS) Videos: $($script:GREEN)$($mediaFiles.Videos.Count)$($script:NC) files ($($script:CYAN)$(Format-ByteSize -Bytes $totalSize.Videos)$($script:NC))"
            Write-Host ""
            $grandTotal = $totalSize.Images + $totalSize.Videos
            Write-Host "  Total: $($script:YELLOW)$(Format-ByteSize -Bytes $grandTotal)$($script:NC)"
            Write-Host ""

            # Show largest files
            if ($mediaFiles.Videos.Count -gt 0) {
                Write-Host "$($script:PURPLE_BOLD)Largest Videos$($script:NC)"
                $mediaFiles.Videos | Sort-Object Length -Descending | Select-Object -First 10 | ForEach-Object {
                    $relativePath = $_.FullName.Substring(3)  # Remove drive letter
                    if ($relativePath.Length -gt 60) {
                        $relativePath = "..." + $relativePath.Substring($relativePath.Length - 57)
                    }
                    Write-Host "  $(Format-ByteSize -Bytes $_.Length) - $relativePath"
                }
                Write-Host ""
            }

            Write-Host "To transfer media to another drive, run:"
            Write-Host "  $($script:CYAN)mole media transfer $sourceDrive`: <destination-drive>:$($script:NC)"
        }

        "transfer" {
            # Transfer media from source to destination
            $sourceDrive = if ($RemainingArgs.Count -gt 1) { $RemainingArgs[1].TrimEnd(':').ToUpper() } else { "" }
            $destDrive = if ($RemainingArgs.Count -gt 2) { $RemainingArgs[2].TrimEnd(':').ToUpper() } else { "" }

            if ([string]::IsNullOrEmpty($sourceDrive) -or [string]::IsNullOrEmpty($destDrive)) {
                Write-MoleError "Usage: mole media transfer <source-drive>: <dest-drive>:"
                Write-Host "Example: mole media transfer C: E:"
                return
            }

            $sourcePath = "${sourceDrive}:\"
            $destPath = "${destDrive}:\Media"

            if (-not (Test-Path $sourcePath)) {
                Write-MoleError "Source drive $sourceDrive`: does not exist"
                return
            }
            if (-not (Test-Path "${destDrive}:\")) {
                Write-MoleError "Destination drive $destDrive`: does not exist"
                return
            }

            Write-Host "$($script:PURPLE_BOLD)Media Transfer$($script:NC)"
            Write-Host "From: $($script:CYAN)$sourceDrive`:$($script:NC) -> To: $($script:GREEN)$destPath$($script:NC)"
            if ($DryRun) {
                Write-Host "$($script:YELLOW)(DRY RUN - no files will be moved)$($script:NC)"
            }
            Write-Host ""

            # Directories to skip
            $skipDirs = @('Windows', 'Program Files', 'Program Files (x86)', '$Recycle.Bin',
                          'System Volume Information', 'ProgramData', 'Recovery', 'PerfLogs',
                          'AppData', 'Application Data', 'Local Settings')

            # Also skip the destination if it's on the same drive
            if ($sourceDrive -eq $destDrive) {
                $skipDirs += 'Media'
            }

            Write-Host "  Scanning for media files..." -NoNewline

            $mediaFiles = @()
            $topDirs = Get-ChildItem -Path $sourcePath -Directory -Force -ErrorAction SilentlyContinue |
                Where-Object { $skipDirs -notcontains $_.Name }

            foreach ($topDir in $topDirs) {
                Write-Host "`r  Scanning: $($topDir.Name.PadRight(40))" -NoNewline

                try {
                    $files = Get-ChildItem -Path $topDir.FullName -Recurse -File -Force -ErrorAction SilentlyContinue |
                        Where-Object { $allMediaExtensions -contains $_.Extension.ToLower() }
                    $mediaFiles += $files
                }
                catch {
                    # Skip inaccessible directories
                }
            }

            # Also check Users folder specifically for common media locations
            $usersPath = "${sourceDrive}:\Users"
            if (Test-Path $usersPath) {
                $userDirs = Get-ChildItem -Path $usersPath -Directory -Force -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -ne 'Default' -and $_.Name -ne 'Public' -and $_.Name -ne 'Default User' }

                foreach ($userDir in $userDirs) {
                    $mediaLocations = @('Pictures', 'Videos', 'Downloads', 'Desktop', 'Documents',
                                        'OneDrive\Pictures', 'OneDrive\Videos')

                    foreach ($loc in $mediaLocations) {
                        $locPath = Join-Path $userDir.FullName $loc
                        if (Test-Path $locPath) {
                            Write-Host "`r  Scanning: Users\$($userDir.Name)\$loc".PadRight(50) -NoNewline
                            try {
                                $files = Get-ChildItem -Path $locPath -Recurse -File -Force -ErrorAction SilentlyContinue |
                                    Where-Object { $allMediaExtensions -contains $_.Extension.ToLower() }
                                $mediaFiles += $files
                            }
                            catch { }
                        }
                    }
                }
            }

            Write-Host "`r" + (" " * 60) + "`r"

            # Remove duplicates
            $mediaFiles = $mediaFiles | Select-Object -Unique

            if ($mediaFiles.Count -eq 0) {
                Write-Host "  No media files found."
                return
            }

            $totalSize = ($mediaFiles | Measure-Object -Property Length -Sum).Sum
            $imageCount = ($mediaFiles | Where-Object { $imageExtensions -contains $_.Extension.ToLower() }).Count
            $videoCount = ($mediaFiles | Where-Object { $videoExtensions -contains $_.Extension.ToLower() }).Count

            Write-Host ""
            Write-Host "  Found: $($script:GREEN)$($mediaFiles.Count)$($script:NC) files ($(Format-ByteSize -Bytes $totalSize))"
            Write-Host "         $imageCount images, $videoCount videos"
            Write-Host ""

            # Check destination space
            $destDriveInfo = Get-PSDrive -Name $destDrive -ErrorAction SilentlyContinue
            if ($destDriveInfo) {
                $freeSpace = $destDriveInfo.Free
                if ($freeSpace -lt $totalSize) {
                    Write-MoleError "Not enough space on $destDrive`: ($(Format-ByteSize -Bytes $freeSpace) free, need $(Format-ByteSize -Bytes $totalSize))"
                    return
                }
                Write-Host "  Destination has $(Format-ByteSize -Bytes $freeSpace) free"
            }

            if (-not $DryRun -and -not $Yes) {
                Write-Host ""
                $response = Read-Host "Transfer $($mediaFiles.Count) files to $destPath`? [y/N]"
                if ($response -ne 'y' -and $response -ne 'Y') {
                    Write-Host "Cancelled."
                    return
                }
            }

            # Create destination structure
            $destImages = Join-Path $destPath "Images"
            $destVideos = Join-Path $destPath "Videos"

            if (-not $DryRun) {
                New-Item -Path $destImages -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
                New-Item -Path $destVideos -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
            }

            Write-Host ""
            Write-Host "  Transferring files..."

            $movedCount = 0
            $movedSize = 0
            $errorCount = 0

            foreach ($file in $mediaFiles) {
                $ext = $file.Extension.ToLower()

                # Determine destination folder
                if ($imageExtensions -contains $ext) {
                    $destFolder = $destImages
                }
                else {
                    $destFolder = $destVideos
                }

                # Create year/month subfolder based on file date
                $fileDate = $file.LastWriteTime
                $yearMonth = $fileDate.ToString("yyyy\\MM")
                $finalDest = Join-Path $destFolder $yearMonth
                $destFile = Join-Path $finalDest $file.Name

                # Handle duplicate filenames
                $counter = 1
                while (Test-Path $destFile) {
                    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
                    $extension = $file.Extension
                    $destFile = Join-Path $finalDest "$baseName`_$counter$extension"
                    $counter++
                }

                if ($DryRun) {
                    $relativeDest = $destFile.Substring(3)  # Remove drive letter
                    if ($movedCount -lt 20) {
                        Write-Host "    $($script:GRAY)Would move:$($script:NC) $($file.Name) -> $yearMonth\"
                    }
                    elseif ($movedCount -eq 20) {
                        Write-Host "    $($script:GRAY)... and more$($script:NC)"
                    }
                    $movedCount++
                    $movedSize += $file.Length
                }
                else {
                    try {
                        # Create destination folder
                        if (-not (Test-Path $finalDest)) {
                            New-Item -Path $finalDest -ItemType Directory -Force | Out-Null
                        }

                        # Move file
                        Move-Item -Path $file.FullName -Destination $destFile -Force -ErrorAction Stop
                        $movedCount++
                        $movedSize += $file.Length

                        # Progress update every 50 files
                        if ($movedCount % 50 -eq 0) {
                            $pct = [math]::Round(($movedCount / $mediaFiles.Count) * 100)
                            Write-Host "`r    Progress: $movedCount / $($mediaFiles.Count) ($pct%)" -NoNewline
                        }
                    }
                    catch {
                        $errorCount++
                        Write-MoleDebug "Failed to move $($file.Name): $($_.Exception.Message)"
                    }
                }
            }

            Write-Host "`r" + (" " * 60) + "`r"
            Write-Host ""
            Write-Host ("-" * 50)

            if ($DryRun) {
                Write-Host "$($script:YELLOW)DRY RUN COMPLETE$($script:NC)"
                Write-Host "  Would transfer: $movedCount files ($(Format-ByteSize -Bytes $movedSize))"
                Write-Host ""
                Write-Host "To actually transfer, run without -n flag:"
                Write-Host "  $($script:CYAN)mole media transfer $sourceDrive`: $destDrive`:$($script:NC)"
            }
            else {
                Write-Host "$($script:GREEN)TRANSFER COMPLETE$($script:NC)"
                Write-Host "  Transferred: $movedCount files ($(Format-ByteSize -Bytes $movedSize))"
                if ($errorCount -gt 0) {
                    Write-Host "  $($script:YELLOW)Errors: $errorCount files could not be moved$($script:NC)"
                }
                Write-Host "  Destination: $destPath"
                Write-Host "    - Images organized in: $destImages\<year>\<month>\"
                Write-Host "    - Videos organized in: $destVideos\<year>\<month>\"
            }
        }

        default {
            Write-Host "$($script:PURPLE_BOLD)Media Manager$($script:NC)"
            Write-Host "Find and transfer images and videos between drives"
            Write-Host ""
            Write-Host "USAGE:"
            Write-Host "  mole media scan <drive>:          Scan drive for media files"
            Write-Host "  mole media transfer <src>: <dst>: Transfer media between drives"
            Write-Host ""
            Write-Host "OPTIONS:"
            Write-Host "  -n, -DryRun    Preview transfer without moving files"
            Write-Host "  -Yes           Skip confirmation prompt"
            Write-Host ""
            Write-Host "EXAMPLES:"
            Write-Host "  mole media scan C:              Find all media on C: drive"
            Write-Host "  mole media transfer C: E:       Move media from C: to E:\Media"
            Write-Host "  mole media transfer C: E: -n    Preview what would be moved"
            Write-Host ""
            Write-Host "SUPPORTED FORMATS:"
            Write-Host "  Images: jpg, jpeg, png, gif, bmp, webp, heic, tiff, raw, cr2, nef, arw, dng"
            Write-Host "  Videos: mp4, mkv, avi, mov, wmv, flv, webm, m4v, mpeg, mpg, 3gp, ts, mts"
            Write-Host ""
            Write-Host "Files are organized by date: <dest>\Images\<year>\<month>\"
        }
    }
}

# ============================================================================
# Main Entry Point
# ============================================================================
function Main {
    # Handle no command
    if ([string]::IsNullOrWhiteSpace($Command)) {
        Show-Help
        return
    }

    switch ($Command) {
        "clean" {
            Invoke-CleanCommand
        }
        "analyze" {
            Invoke-AnalyzeCommand
        }
        "status" {
            Invoke-StatusCommand
        }
        "whitelist" {
            Invoke-WhitelistCommand
        }
        "purge" {
            Invoke-PurgeCommand
        }
        "optimize" {
            Invoke-OptimizeCommand
        }
        "media" {
            Invoke-MediaCommand
        }
        "help" {
            Show-Help
        }
        "version" {
            Show-Version
        }
        default {
            Write-MoleError "Unknown command: $Command"
            Write-Host "Run 'mole help' for usage information."
        }
    }
}

# Run
Main
