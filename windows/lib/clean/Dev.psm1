# Mole Windows - Developer Tools Cleanup Module
# Cleans caches for npm, pip, cargo, gradle, go, docker, and other dev tools

#Requires -Version 5.1

# Import dependencies
$coreModules = @(
    (Join-Path $PSScriptRoot "..\core\Base.psm1"),
    (Join-Path $PSScriptRoot "..\core\Log.psm1"),
    (Join-Path $PSScriptRoot "..\core\FileOps.psm1"),
    (Join-Path $PSScriptRoot "..\core\UI.psm1")
)

foreach ($module in $coreModules) {
    Import-Module $module -Force -DisableNameChecking -ErrorAction SilentlyContinue
}

# Prevent multiple loading
if ($script:MOLE_CLEAN_DEV_LOADED) { return }
$script:MOLE_CLEAN_DEV_LOADED = $true

# ============================================================================
# npm/pnpm/yarn/bun Cleanup
# ============================================================================

function Clear-NpmCache {
    <#
    .SYNOPSIS
        Cleans npm, pnpm, yarn, and bun caches.
    #>
    Start-MoleSection -Title "Node.js Package Managers"

    # npm cache
    $npmCache = Join-Path $env:LOCALAPPDATA "npm-cache"
    if (-not (Test-Path $npmCache)) {
        $npmCache = Join-Path $env:APPDATA "npm-cache"
    }
    if (Test-Path $npmCache) {
        if (Get-MoleDryRun) {
            $size = Get-PathSize -Path $npmCache
            Write-MoleDryRun "npm cache - would clean $(Format-ByteSize -Bytes $size)"
        }
        else {
            # Use npm cache clean if available
            if (Get-Command npm -ErrorAction SilentlyContinue) {
                try {
                    npm cache clean --force 2>$null
                    Set-MoleActivity
                    Write-MoleSuccess "npm cache cleaned"
                }
                catch {
                    Invoke-SafeClean -Path "$npmCache\*" -Description "npm cache"
                }
            }
            else {
                Invoke-SafeClean -Path "$npmCache\*" -Description "npm cache"
            }
        }
    }

    # pnpm store
    $pnpmStore = Join-Path $env:LOCALAPPDATA "pnpm\store"
    if (-not (Test-Path $pnpmStore)) {
        $pnpmStore = Join-Path $env:USERPROFILE ".pnpm-store"
    }
    if (Test-Path $pnpmStore) {
        if (Get-Command pnpm -ErrorAction SilentlyContinue) {
            if (Get-MoleDryRun) {
                $size = Get-PathSize -Path $pnpmStore
                Write-MoleDryRun "pnpm store - would clean $(Format-ByteSize -Bytes $size)"
            }
            else {
                try {
                    pnpm store prune 2>$null
                    Set-MoleActivity
                    Write-MoleSuccess "pnpm store pruned"
                }
                catch {
                    Write-MoleDebug "pnpm store prune failed: $($_.Exception.Message)"
                }
            }
        }
    }

    # yarn cache
    $yarnCache = Join-Path $env:LOCALAPPDATA "Yarn\Cache"
    if (-not (Test-Path $yarnCache)) {
        $yarnCache = Join-Path $env:USERPROFILE ".cache\yarn"
    }
    if (Test-Path $yarnCache) {
        Invoke-SafeClean -Path "$yarnCache\*" -Description "Yarn cache"
    }

    # bun cache
    $bunCache = Join-Path $env:USERPROFILE ".bun\install\cache"
    if (Test-Path $bunCache) {
        Invoke-SafeClean -Path "$bunCache\*" -Description "Bun cache"
    }

    Stop-MoleSection
}

# ============================================================================
# Python/pip Cleanup
# ============================================================================

function Clear-PythonCache {
    <#
    .SYNOPSIS
        Cleans pip, pyenv, poetry, and other Python tool caches.
    #>
    Start-MoleSection -Title "Python Package Managers"

    # pip cache
    $pipCache = Join-Path $env:LOCALAPPDATA "pip\Cache"
    if (Test-Path $pipCache) {
        if (Get-MoleDryRun) {
            $size = Get-PathSize -Path $pipCache
            Write-MoleDryRun "pip cache - would clean $(Format-ByteSize -Bytes $size)"
        }
        else {
            if (Get-Command pip3 -ErrorAction SilentlyContinue) {
                try {
                    pip3 cache purge 2>$null
                    Set-MoleActivity
                    Write-MoleSuccess "pip cache purged"
                }
                catch {
                    Invoke-SafeClean -Path "$pipCache\*" -Description "pip cache"
                }
            }
            elseif (Get-Command pip -ErrorAction SilentlyContinue) {
                try {
                    pip cache purge 2>$null
                    Set-MoleActivity
                    Write-MoleSuccess "pip cache purged"
                }
                catch {
                    Invoke-SafeClean -Path "$pipCache\*" -Description "pip cache"
                }
            }
            else {
                Invoke-SafeClean -Path "$pipCache\*" -Description "pip cache"
            }
        }
    }

    # pyenv cache
    $pyenvCache = Join-Path $env:USERPROFILE ".pyenv\cache"
    if (Test-Path $pyenvCache) {
        Invoke-SafeClean -Path "$pyenvCache\*" -Description "pyenv cache"
    }

    # poetry cache
    $poetryCache = Join-Path $env:LOCALAPPDATA "pypoetry\Cache"
    if (-not (Test-Path $poetryCache)) {
        $poetryCache = Join-Path $env:USERPROFILE ".cache\pypoetry"
    }
    if (Test-Path $poetryCache) {
        Invoke-SafeClean -Path "$poetryCache\*" -Description "Poetry cache"
    }

    # uv cache
    $uvCache = Join-Path $env:LOCALAPPDATA "uv\cache"
    if (-not (Test-Path $uvCache)) {
        $uvCache = Join-Path $env:USERPROFILE ".cache\uv"
    }
    if (Test-Path $uvCache) {
        Invoke-SafeClean -Path "$uvCache\*" -Description "uv cache"
    }

    # pytest cache
    $pytestCache = Join-Path $env:USERPROFILE ".pytest_cache"
    if (Test-Path $pytestCache) {
        Invoke-SafeClean -Path "$pytestCache\*" -Description "Pytest cache"
    }

    # mypy cache
    $mypyCache = Join-Path $env:USERPROFILE ".mypy_cache"
    if (Test-Path $mypyCache) {
        Invoke-SafeClean -Path "$mypyCache\*" -Description "MyPy cache"
    }

    # ruff cache
    $ruffCache = Join-Path $env:LOCALAPPDATA "ruff\cache"
    if (-not (Test-Path $ruffCache)) {
        $ruffCache = Join-Path $env:USERPROFILE ".cache\ruff"
    }
    if (Test-Path $ruffCache) {
        Invoke-SafeClean -Path "$ruffCache\*" -Description "Ruff cache"
    }

    # Conda packages cache
    $condaCache = Join-Path $env:USERPROFILE ".conda\pkgs"
    if (Test-Path $condaCache) {
        Invoke-SafeClean -Path "$condaCache\*" -Description "Conda packages cache"
    }

    # Anaconda packages cache
    $anacondaCache = Join-Path $env:USERPROFILE "anaconda3\pkgs"
    if (Test-Path $anacondaCache) {
        Invoke-SafeClean -Path "$anacondaCache\*" -Description "Anaconda packages cache"
    }

    # Weights & Biases (wandb) cache
    $wandbCache = Join-Path $env:USERPROFILE ".cache\wandb"
    if (-not (Test-Path $wandbCache)) {
        $wandbCache = Join-Path $env:LOCALAPPDATA "wandb\cache"
    }
    if (Test-Path $wandbCache) {
        Invoke-SafeClean -Path "$wandbCache\*" -Description "Weights & Biases cache"
    }

    # Jupyter runtime cache
    $jupyterRuntime = Join-Path $env:APPDATA "jupyter\runtime"
    if (Test-Path $jupyterRuntime) {
        Invoke-SafeClean -Path "$jupyterRuntime\*" -Description "Jupyter runtime cache"
    }

    Stop-MoleSection
}

# ============================================================================
# Go Cleanup
# ============================================================================

function Clear-GoCache {
    <#
    .SYNOPSIS
        Cleans Go build and module caches.
    #>
    Start-MoleSection -Title "Go Cache"

    if (Get-Command go -ErrorAction SilentlyContinue) {
        if (Get-MoleDryRun) {
            # Calculate size
            $goCachePath = & go env GOCACHE 2>$null
            $goModCachePath = & go env GOMODCACHE 2>$null

            $totalSize = 0
            if ($goCachePath -and (Test-Path $goCachePath)) {
                $totalSize += Get-PathSize -Path $goCachePath
            }
            if ($goModCachePath -and (Test-Path $goModCachePath)) {
                $totalSize += Get-PathSize -Path $goModCachePath
            }

            if ($totalSize -gt 0) {
                Write-MoleDryRun "Go cache - would clean $(Format-ByteSize -Bytes $totalSize)"
            }
        }
        else {
            try {
                go clean -cache 2>$null
                go clean -modcache 2>$null
                Set-MoleActivity
                Write-MoleSuccess "Go cache cleaned"
            }
            catch {
                Write-MoleDebug "Go cache clean failed: $($_.Exception.Message)"
            }
        }
    }

    Stop-MoleSection
}

# ============================================================================
# Rust/Cargo Cleanup
# ============================================================================

function Clear-RustCache {
    <#
    .SYNOPSIS
        Cleans Rust cargo and rustup caches.
    #>
    Start-MoleSection -Title "Rust/Cargo Cache"

    # Cargo registry cache
    $cargoCache = Join-Path $env:USERPROFILE ".cargo\registry\cache"
    if (Test-Path $cargoCache) {
        Invoke-SafeClean -Path "$cargoCache\*" -Description "Cargo registry cache"
    }

    # Cargo git cache
    $cargoGit = Join-Path $env:USERPROFILE ".cargo\git"
    if (Test-Path $cargoGit) {
        Invoke-SafeClean -Path "$cargoGit\db\*" -Description "Cargo git cache"
    }

    # Rustup downloads
    $rustupDownloads = Join-Path $env:USERPROFILE ".rustup\downloads"
    if (Test-Path $rustupDownloads) {
        Invoke-SafeClean -Path "$rustupDownloads\*" -Description "Rustup downloads"
    }

    # Check for multiple toolchains
    $toolchainsPath = Join-Path $env:USERPROFILE ".rustup\toolchains"
    if (Test-Path $toolchainsPath) {
        $toolchains = Get-ChildItem -Path $toolchainsPath -Directory -ErrorAction SilentlyContinue
        if ($toolchains.Count -gt 1) {
            Set-MoleActivity
            Write-Host "  Found $($script:GREEN)$($toolchains.Count)$($script:NC) Rust toolchains"
            Write-Host "  You can list them with: $($script:GRAY)rustup toolchain list$($script:NC)"
            Write-Host "  Remove unused with: $($script:GRAY)rustup toolchain uninstall <name>$($script:NC)"
        }
    }

    Stop-MoleSection
}

# ============================================================================
# Docker Cleanup
# ============================================================================

function Clear-DockerCache {
    <#
    .SYNOPSIS
        Cleans Docker build cache and dangling images.
    #>
    Start-MoleSection -Title "Docker Cache"

    if (Get-Command docker -ErrorAction SilentlyContinue) {
        # Check if Docker daemon is running
        $dockerRunning = $false
        try {
            $null = docker info 2>$null
            $dockerRunning = $true
        }
        catch {
            Write-MoleDebug "Docker daemon not running, skipping Docker cleanup"
        }

        if ($dockerRunning) {
            if (Get-MoleDryRun) {
                Set-MoleActivity
                Write-MoleDryRun "Docker build cache - would clean"
            }
            else {
                try {
                    docker builder prune -af 2>$null
                    Set-MoleActivity
                    Write-MoleSuccess "Docker build cache cleaned"
                }
                catch {
                    Write-MoleDebug "Docker builder prune failed: $($_.Exception.Message)"
                }
            }
        }
    }

    # Docker Desktop cache (Windows specific)
    $dockerCache = Join-Path $env:LOCALAPPDATA "Docker\wsl\data"
    # Note: Don't clean the WSL data, just log its size
    if (Test-Path $dockerCache) {
        $size = Get-PathSize -Path $dockerCache
        if ($size -gt 1GB) {
            Write-Host "  $($script:ICON_LIST) Docker WSL disk: $(Format-ByteSize -Bytes $size)"
            Write-Host "    $($script:GRAY)Reclaim space via Docker Desktop settings$($script:NC)"
        }
    }

    Stop-MoleSection
}

# ============================================================================
# JVM Ecosystem Cleanup
# ============================================================================

function Clear-JvmCache {
    <#
    .SYNOPSIS
        Cleans Gradle, Maven, SBT, and Ivy caches.
    #>
    Start-MoleSection -Title "JVM Ecosystem"

    # Gradle caches
    $gradleCache = Join-Path $env:USERPROFILE ".gradle\caches"
    if (Test-Path $gradleCache) {
        Invoke-SafeClean -Path "$gradleCache\*" -Description "Gradle caches"
    }

    # Gradle daemon logs
    $gradleDaemon = Join-Path $env:USERPROFILE ".gradle\daemon"
    if (Test-Path $gradleDaemon) {
        Invoke-SafeClean -Path "$gradleDaemon\*" -Description "Gradle daemon logs"
    }

    # Maven repository (be careful - this is also a local repo)
    # Only clean the resolved-guava-versions.xml and similar cache files
    $mavenCache = Join-Path $env:USERPROFILE ".m2\repository"
    if (Test-Path $mavenCache) {
        # Just report size, don't auto-clean Maven repo
        $size = Get-PathSize -Path $mavenCache
        if ($size -gt 100MB) {
            Write-Host "  $($script:ICON_LIST) Maven repository: $(Format-ByteSize -Bytes $size)"
            Write-Host "    $($script:GRAY)Clean manually if needed$($script:NC)"
        }
    }

    # SBT cache
    $sbtCache = Join-Path $env:USERPROFILE ".sbt"
    if (Test-Path $sbtCache) {
        Invoke-SafeClean -Path "$sbtCache\*.log" -Description "SBT logs"
        Invoke-SafeClean -Path "$sbtCache\boot\*" -Description "SBT boot cache"
    }

    # Ivy cache
    $ivyCache = Join-Path $env:USERPROFILE ".ivy2\cache"
    if (Test-Path $ivyCache) {
        Invoke-SafeClean -Path "$ivyCache\*" -Description "Ivy cache"
    }

    Stop-MoleSection
}

# ============================================================================
# Frontend Build Tools
# ============================================================================

function Clear-FrontendCache {
    <#
    .SYNOPSIS
        Cleans TypeScript, Webpack, Vite, Turbo, and other frontend tool caches.
    #>
    Start-MoleSection -Title "Frontend Build Tools"

    # TypeScript cache
    $tsCache = Join-Path $env:USERPROFILE ".cache\typescript"
    if (Test-Path $tsCache) {
        Invoke-SafeClean -Path "$tsCache\*" -Description "TypeScript cache"
    }

    # Turbo cache
    $turboCache = Join-Path $env:USERPROFILE ".turbo"
    if (Test-Path $turboCache) {
        Invoke-SafeClean -Path "$turboCache\*" -Description "Turbo cache"
    }

    # Vite cache
    $viteCache = Join-Path $env:USERPROFILE ".vite"
    if (Test-Path $viteCache) {
        Invoke-SafeClean -Path "$viteCache\*" -Description "Vite cache"
    }

    # Parcel cache
    $parcelCache = Join-Path $env:USERPROFILE ".parcel-cache"
    if (Test-Path $parcelCache) {
        Invoke-SafeClean -Path "$parcelCache\*" -Description "Parcel cache"
    }

    # ESLint cache
    $eslintCache = Join-Path $env:USERPROFILE ".eslintcache"
    if (Test-Path $eslintCache) {
        Invoke-SafeClean -Path $eslintCache -Description "ESLint cache"
    }

    # node-gyp cache
    $nodeGypCache = Join-Path $env:LOCALAPPDATA "node-gyp\Cache"
    if (-not (Test-Path $nodeGypCache)) {
        $nodeGypCache = Join-Path $env:USERPROFILE ".node-gyp"
    }
    if (Test-Path $nodeGypCache) {
        Invoke-SafeClean -Path "$nodeGypCache\*" -Description "node-gyp cache"
    }

    # Electron cache
    $electronCache = Join-Path $env:LOCALAPPDATA "electron\Cache"
    if (-not (Test-Path $electronCache)) {
        $electronCache = Join-Path $env:USERPROFILE ".cache\electron"
    }
    if (Test-Path $electronCache) {
        Invoke-SafeClean -Path "$electronCache\*" -Description "Electron cache"
    }

    # Puppeteer browser cache
    $puppeteerCache = Join-Path $env:USERPROFILE ".cache\puppeteer"
    if (-not (Test-Path $puppeteerCache)) {
        $puppeteerCache = Join-Path $env:LOCALAPPDATA "puppeteer"
    }
    if (Test-Path $puppeteerCache) {
        Invoke-SafeClean -Path "$puppeteerCache\*" -Description "Puppeteer browser cache"
    }

    # Playwright browsers cache
    $playwrightCache = Join-Path $env:LOCALAPPDATA "ms-playwright"
    if (Test-Path $playwrightCache) {
        $size = Get-PathSize -Path $playwrightCache
        if ($size -gt 100MB) {
            Write-Host "  $($script:ICON_LIST) Playwright browsers: $(Format-ByteSize -Bytes $size)"
            Write-Host "    $($script:GRAY)Clean with: npx playwright uninstall --all$($script:NC)"
        }
    }

    Stop-MoleSection
}

# ============================================================================
# Cloud & DevOps Tools
# ============================================================================

function Clear-CloudToolsCache {
    <#
    .SYNOPSIS
        Cleans Kubernetes, AWS, Azure, GCloud, and Terraform caches.
    #>
    Start-MoleSection -Title "Cloud & DevOps Tools"

    # Kubernetes cache
    $kubeCache = Join-Path $env:USERPROFILE ".kube\cache"
    if (Test-Path $kubeCache) {
        Invoke-SafeClean -Path "$kubeCache\*" -Description "Kubernetes cache"
    }

    # AWS CLI cache
    $awsCache = Join-Path $env:USERPROFILE ".aws\cli\cache"
    if (Test-Path $awsCache) {
        Invoke-SafeClean -Path "$awsCache\*" -Description "AWS CLI cache"
    }

    # Azure CLI cache/logs
    $azureLogs = Join-Path $env:USERPROFILE ".azure\logs"
    if (Test-Path $azureLogs) {
        Invoke-SafeClean -Path "$azureLogs\*" -Description "Azure CLI logs"
    }

    # Google Cloud logs
    $gcloudLogs = Join-Path $env:APPDATA "gcloud\logs"
    if (Test-Path $gcloudLogs) {
        Invoke-SafeClean -Path "$gcloudLogs\*" -Description "Google Cloud logs"
    }

    # Terraform cache (plugin cache, not state!)
    $terraformCache = Join-Path $env:USERPROFILE ".terraform.d\plugin-cache"
    if (Test-Path $terraformCache) {
        Invoke-SafeClean -Path "$terraformCache\*" -Description "Terraform plugin cache"
    }

    # Helm cache
    $helmCache = Join-Path $env:LOCALAPPDATA "helm\cache"
    if (Test-Path $helmCache) {
        Invoke-SafeClean -Path "$helmCache\*" -Description "Helm cache"
    }

    Stop-MoleSection
}

# ============================================================================
# IDE & Editor Caches
# ============================================================================

function Clear-IdeCache {
    <#
    .SYNOPSIS
        Cleans VS Code, JetBrains, and other IDE caches.
    #>
    Start-MoleSection -Title "IDE & Editor Caches"

    # VS Code caches (not settings!)
    $vscodeCacheDir = Join-Path $env:APPDATA "Code\Cache"
    if (Test-Path $vscodeCacheDir) {
        Invoke-SafeClean -Path "$vscodeCacheDir\*" -Description "VS Code cache"
    }

    $vscodeCachedData = Join-Path $env:APPDATA "Code\CachedData"
    if (Test-Path $vscodeCachedData) {
        Invoke-SafeClean -Path "$vscodeCachedData\*" -Description "VS Code cached data"
    }

    $vscodeGPUCache = Join-Path $env:APPDATA "Code\GPUCache"
    if (Test-Path $vscodeGPUCache) {
        Invoke-SafeClean -Path "$vscodeGPUCache\*" -Description "VS Code GPU cache"
    }

    # VS Code Insiders
    $vscodeInsidersCache = Join-Path $env:APPDATA "Code - Insiders\Cache"
    if (Test-Path $vscodeInsidersCache) {
        Invoke-SafeClean -Path "$vscodeInsidersCache\*" -Description "VS Code Insiders cache"
    }

    # Cursor
    $cursorCache = Join-Path $env:APPDATA "Cursor\Cache"
    if (Test-Path $cursorCache) {
        Invoke-SafeClean -Path "$cursorCache\*" -Description "Cursor cache"
    }

    # JetBrains IDE caches (in LocalAppData)
    $jetbrainsCache = Join-Path $env:LOCALAPPDATA "JetBrains"
    if (Test-Path $jetbrainsCache) {
        # Clean caches subdirectory in each IDE folder
        $ideDataDirs = Get-ChildItem -Path $jetbrainsCache -Directory -ErrorAction SilentlyContinue
        foreach ($ideDir in $ideDataDirs) {
            $cacheDir = Join-Path $ideDir.FullName "caches"
            if (Test-Path $cacheDir) {
                Invoke-SafeClean -Path "$cacheDir\*" -Description "JetBrains $($ideDir.Name) cache"
            }
        }
    }

    # Sublime Text cache
    $sublimeCache = Join-Path $env:APPDATA "Sublime Text\Cache"
    if (Test-Path $sublimeCache) {
        Invoke-SafeClean -Path "$sublimeCache\*" -Description "Sublime Text cache"
    }

    Stop-MoleSection
}

# ============================================================================
# Other Languages
# ============================================================================

function Clear-OtherLangCache {
    <#
    .SYNOPSIS
        Cleans caches for Ruby, PHP, .NET, Deno, and other languages.
    #>
    Start-MoleSection -Title "Other Languages"

    # Ruby Bundler cache
    $bundlerCache = Join-Path $env:USERPROFILE ".bundle\cache"
    if (Test-Path $bundlerCache) {
        Invoke-SafeClean -Path "$bundlerCache\*" -Description "Ruby Bundler cache"
    }

    # PHP Composer cache
    $composerCache = Join-Path $env:LOCALAPPDATA "Composer\cache"
    if (-not (Test-Path $composerCache)) {
        $composerCache = Join-Path $env:APPDATA "Composer\cache"
    }
    if (Test-Path $composerCache) {
        Invoke-SafeClean -Path "$composerCache\*" -Description "PHP Composer cache"
    }

    # NuGet cache
    $nugetCache = Join-Path $env:LOCALAPPDATA "NuGet\v3-cache"
    if (Test-Path $nugetCache) {
        Invoke-SafeClean -Path "$nugetCache\*" -Description "NuGet cache"
    }

    # Deno cache
    $denoCache = Join-Path $env:LOCALAPPDATA "deno"
    if (Test-Path $denoCache) {
        Invoke-SafeClean -Path "$denoCache\deps\*" -Description "Deno deps cache"
        Invoke-SafeClean -Path "$denoCache\gen\*" -Description "Deno gen cache"
    }

    # Zig cache
    $zigCache = Join-Path $env:LOCALAPPDATA "zig"
    if (Test-Path $zigCache) {
        Invoke-SafeClean -Path "$zigCache\*" -Description "Zig cache"
    }

    # Dart/Flutter pub cache
    $pubCache = Join-Path $env:LOCALAPPDATA "Pub\Cache"
    if (Test-Path $pubCache) {
        Invoke-SafeClean -Path "$pubCache\*" -Description "Dart Pub cache"
    }

    Stop-MoleSection
}

# ============================================================================
# Stale Node Modules Cleanup
# ============================================================================

function Clear-StaleNodeModules {
    <#
    .SYNOPSIS
        Finds and removes node_modules from old/stale projects.
        Only cleans projects where package.json hasn't been modified in 30+ days.
        NEVER touches pnpm store, npm cache, or global node_modules.
    #>
    param(
        [int]$DaysOld = 30
    )

    Start-MoleSection -Title "Stale Node Modules"

    # Paths to NEVER touch - pnpm/npm stores and global locations
    $excludedPaths = @(
        (Join-Path $env:LOCALAPPDATA "pnpm"),
        (Join-Path $env:USERPROFILE ".pnpm-store"),
        (Join-Path $env:LOCALAPPDATA "npm-cache"),
        (Join-Path $env:APPDATA "npm-cache"),
        (Join-Path $env:APPDATA "npm"),
        (Join-Path $env:LOCALAPPDATA "npm"),
        (Join-Path $env:ProgramFiles "nodejs"),
        (Join-Path ${env:ProgramFiles(x86)} "nodejs"),
        # Also exclude any path with these patterns
        "pnpm-store",
        ".pnpm-store",
        "\pnpm\",
        "\.pnpm\"
    )

    # Common directories where developers keep projects
    # Skip OneDrive - too slow to scan and synced files shouldn't be auto-deleted
    $searchDirs = @(
        (Join-Path $env:USERPROFILE "Projects"),
        (Join-Path $env:USERPROFILE "projects"),
        (Join-Path $env:USERPROFILE "Code"),
        (Join-Path $env:USERPROFILE "code"),
        (Join-Path $env:USERPROFILE "Dev"),
        (Join-Path $env:USERPROFILE "dev"),
        (Join-Path $env:USERPROFILE "Development"),
        (Join-Path $env:USERPROFILE "Repos"),
        (Join-Path $env:USERPROFILE "repos"),
        (Join-Path $env:USERPROFILE "src"),
        (Join-Path $env:USERPROFILE "Source"),
        (Join-Path $env:USERPROFILE "workspace"),
        (Join-Path $env:USERPROFILE "Workspace"),
        (Join-Path $env:USERPROFILE "GitHub"),
        (Join-Path $env:USERPROFILE "git")
        # Note: Skipping Desktop/Documents/OneDrive - too slow and risky
    )

    $staleModules = @()
    $cutoffDate = (Get-Date).AddDays(-$DaysOld)

    foreach ($searchDir in $searchDirs) {
        if (-not (Test-Path $searchDir)) {
            continue
        }

        # Find all node_modules directories (limit depth for performance)
        $nodeModulesDirs = Get-ChildItem -Path $searchDir -Filter "node_modules" -Directory -Recurse -Depth 4 -ErrorAction SilentlyContinue

        foreach ($nmDir in $nodeModulesDirs) {
            $nmPath = $nmDir.FullName

            # Skip if path matches any excluded pattern
            $isExcluded = $false
            foreach ($excluded in $excludedPaths) {
                if ($nmPath -like "*$excluded*") {
                    $isExcluded = $true
                    Write-MoleDebug "Skipping excluded path: $nmPath"
                    break
                }
            }
            if ($isExcluded) { continue }

            # Skip if this is inside another node_modules (nested)
            $parentPath = Split-Path $nmPath -Parent
            if ($parentPath -like "*\node_modules\*" -or $parentPath -like "*\node_modules") {
                continue
            }

            # Check for package.json in parent directory
            $packageJson = Join-Path $parentPath "package.json"
            if (-not (Test-Path $packageJson)) {
                continue
            }

            # Check if package.json is older than cutoff
            $packageJsonInfo = Get-Item $packageJson -ErrorAction SilentlyContinue
            if ($packageJsonInfo -and $packageJsonInfo.LastWriteTime -lt $cutoffDate) {
                $size = Get-PathSize -Path $nmPath
                if ($size -gt 1MB) {  # Only report if > 1MB
                    $staleModules += @{
                        Path        = $nmPath
                        ProjectPath = $parentPath
                        Size        = $size
                        LastUsed    = $packageJsonInfo.LastWriteTime
                        DaysOld     = [math]::Floor(((Get-Date) - $packageJsonInfo.LastWriteTime).TotalDays)
                    }
                }
            }
        }
    }

    if ($staleModules.Count -eq 0) {
        Write-MoleSuccess "No stale node_modules found (older than $DaysOld days)"
        Stop-MoleSection
        return
    }

    # Sort by size descending
    $staleModules = $staleModules | Sort-Object { $_.Size } -Descending

    $totalSize = ($staleModules | Measure-Object -Property Size -Sum).Sum

    Write-Host ""
    Write-Host "  Found $($script:YELLOW)$($staleModules.Count)$($script:NC) stale node_modules ($(Format-ByteSize -Bytes $totalSize) total):"
    Write-Host ""

    # Show top entries
    $showCount = [Math]::Min($staleModules.Count, 10)
    for ($i = 0; $i -lt $showCount; $i++) {
        $module = $staleModules[$i]
        $projectName = Split-Path $module.ProjectPath -Leaf
        Write-Host "    $($script:ICON_LIST) $projectName ($($script:GREEN)$(Format-ByteSize -Bytes $module.Size)$($script:NC)) - $($module.DaysOld) days old"
    }

    if ($staleModules.Count -gt 10) {
        Write-Host "    $($script:GRAY)... and $($staleModules.Count - 10) more$($script:NC)"
    }
    Write-Host ""

    if (Get-MoleDryRun) {
        Write-MoleDryRun "Would clean $($staleModules.Count) stale node_modules ($(Format-ByteSize -Bytes $totalSize))"
    }
    else {
        # Clean each stale node_modules
        $cleanedCount = 0
        $cleanedSize = 0

        foreach ($module in $staleModules) {
            try {
                # Double-check it's not an excluded path before deleting
                $safeToDelete = $true
                foreach ($excluded in $excludedPaths) {
                    if ($module.Path -like "*$excluded*") {
                        $safeToDelete = $false
                        break
                    }
                }

                if ($safeToDelete) {
                    Remove-Item -Path $module.Path -Recurse -Force -ErrorAction Stop
                    $cleanedCount++
                    $cleanedSize += $module.Size
                    Set-MoleActivity
                }
            }
            catch {
                Write-MoleDebug "Failed to remove $($module.Path): $($_.Exception.Message)"
            }
        }

        if ($cleanedCount -gt 0) {
            Write-MoleSuccess "Cleaned $cleanedCount stale node_modules ($(Format-ByteSize -Bytes $cleanedSize))"
        }
    }

    Stop-MoleSection
}

# ============================================================================
# ML/AI Model Caches
# ============================================================================

function Clear-MLModelCache {
    <#
    .SYNOPSIS
        Cleans HuggingFace, Ollama, PyTorch, and other ML model caches.
        WARNING: These caches can be VERY large (10-100+ GB).
        Models will need to be re-downloaded after cleaning.
    #>
    Start-MoleSection -Title "ML/AI Model Caches"

    # HuggingFace cache (can be enormous - 10-100+ GB)
    # Check for HF_HOME environment variable first
    $hfHome = $env:HF_HOME
    if (-not $hfHome) {
        $hfHome = Join-Path $env:USERPROFILE ".cache\huggingface"
    }

    if (Test-Path $hfHome) {
        # Hub contains downloaded models
        $hfHub = Join-Path $hfHome "hub"
        if (Test-Path $hfHub) {
            $size = Get-PathSize -Path $hfHub
            if ($size -gt 0) {
                if (Get-MoleDryRun) {
                    Write-MoleDryRun "HuggingFace models (hub) - would clean $(Format-ByteSize -Bytes $size)"
                }
                else {
                    Invoke-SafeClean -Path "$hfHub\*" -Description "HuggingFace models (hub)"
                }
            }
        }

        # Transformers cache (legacy location)
        $hfTransformers = Join-Path $hfHome "transformers"
        if (Test-Path $hfTransformers) {
            Invoke-SafeClean -Path "$hfTransformers\*" -Description "HuggingFace transformers cache"
        }

        # Datasets cache
        $hfDatasets = Join-Path $hfHome "datasets"
        if (Test-Path $hfDatasets) {
            $size = Get-PathSize -Path $hfDatasets
            if ($size -gt 0) {
                if (Get-MoleDryRun) {
                    Write-MoleDryRun "HuggingFace datasets - would clean $(Format-ByteSize -Bytes $size)"
                }
                else {
                    Invoke-SafeClean -Path "$hfDatasets\*" -Description "HuggingFace datasets"
                }
            }
        }

        # Accelerate cache
        $hfAccelerate = Join-Path $hfHome "accelerate"
        if (Test-Path $hfAccelerate) {
            Invoke-SafeClean -Path "$hfAccelerate\*" -Description "HuggingFace accelerate cache"
        }

        # Token (don't clean - it's auth)
        # $hfToken = Join-Path $hfHome "token" - SKIP
    }

    # Ollama models (also can be huge)
    $ollamaModels = Join-Path $env:USERPROFILE ".ollama\models"
    if (Test-Path $ollamaModels) {
        $size = Get-PathSize -Path $ollamaModels
        if ($size -gt 100MB) {
            Write-Host "  $($script:ICON_LIST) Ollama models: $(Format-ByteSize -Bytes $size)"
            Write-Host "    $($script:GRAY)Clean with: ollama rm <model-name>$($script:NC)"
            Write-Host "    $($script:GRAY)List models: ollama list$($script:NC)"
        }
    }

    # PyTorch hub cache
    $torchHub = Join-Path $env:USERPROFILE ".cache\torch\hub"
    if (Test-Path $torchHub) {
        Invoke-SafeClean -Path "$torchHub\*" -Description "PyTorch hub cache"
    }

    # PyTorch checkpoints
    $torchCheckpoints = Join-Path $env:USERPROFILE ".cache\torch\checkpoints"
    if (Test-Path $torchCheckpoints) {
        Invoke-SafeClean -Path "$torchCheckpoints\*" -Description "PyTorch checkpoints"
    }

    # Keras models
    $kerasModels = Join-Path $env:USERPROFILE ".keras\models"
    if (Test-Path $kerasModels) {
        Invoke-SafeClean -Path "$kerasModels\*" -Description "Keras models cache"
    }

    # TensorFlow hub cache
    $tfCache = Join-Path $env:LOCALAPPDATA "tf_cache"
    if (-not (Test-Path $tfCache)) {
        $tfCache = Join-Path $env:USERPROFILE ".cache\tensorflow_hub"
    }
    if (Test-Path $tfCache) {
        Invoke-SafeClean -Path "$tfCache\*" -Description "TensorFlow hub cache"
    }

    # Sentence Transformers cache
    $stCache = Join-Path $env:USERPROFILE ".cache\torch\sentence_transformers"
    if (Test-Path $stCache) {
        Invoke-SafeClean -Path "$stCache\*" -Description "Sentence Transformers cache"
    }

    # OpenAI Whisper cache
    $whisperCache = Join-Path $env:USERPROFILE ".cache\whisper"
    if (Test-Path $whisperCache) {
        Invoke-SafeClean -Path "$whisperCache\*" -Description "Whisper models cache"
    }

    # Stable Diffusion / ComfyUI models (common locations)
    $sdModels = Join-Path $env:USERPROFILE ".cache\stable-diffusion"
    if (Test-Path $sdModels) {
        $size = Get-PathSize -Path $sdModels
        if ($size -gt 100MB) {
            Write-Host "  $($script:ICON_LIST) Stable Diffusion cache: $(Format-ByteSize -Bytes $size)"
            Write-Host "    $($script:GRAY)Clean manually if needed$($script:NC)"
        }
    }

    # LangChain cache
    $langchainCache = Join-Path $env:USERPROFILE ".cache\langchain"
    if (Test-Path $langchainCache) {
        Invoke-SafeClean -Path "$langchainCache\*" -Description "LangChain cache"
    }

    # NLTK data
    $nltkData = Join-Path $env:APPDATA "nltk_data"
    if (Test-Path $nltkData) {
        $size = Get-PathSize -Path $nltkData
        if ($size -gt 100MB) {
            Write-Host "  $($script:ICON_LIST) NLTK data: $(Format-ByteSize -Bytes $size)"
            Write-Host "    $($script:GRAY)Clean manually if needed$($script:NC)"
        }
    }

    # Spacy models
    $spacyData = Join-Path $env:LOCALAPPDATA "spacy\data"
    if (Test-Path $spacyData) {
        $size = Get-PathSize -Path $spacyData
        if ($size -gt 100MB) {
            Write-Host "  $($script:ICON_LIST) SpaCy models: $(Format-ByteSize -Bytes $size)"
            Write-Host "    $($script:GRAY)Clean manually if needed$($script:NC)"
        }
    }

    Stop-MoleSection
}

# ============================================================================
# Master Developer Tools Cleanup Function
# ============================================================================

function Invoke-DevCleanup {
    <#
    .SYNOPSIS
        Performs all developer tools cleanup operations.
    .OUTPUTS
        Hashtable with total CleanedSize.
    #>
    Write-MoleInfo "Starting developer tools cleanup..."

    Clear-NpmCache
    Clear-PythonCache
    Clear-GoCache
    Clear-RustCache
    Clear-DockerCache
    Clear-JvmCache
    Clear-FrontendCache
    Clear-CloudToolsCache
    Clear-IdeCache
    Clear-OtherLangCache
    Clear-MLModelCache
    Clear-StaleNodeModules

    return @{
        CleanedSize = 0  # Size tracking would require more integration
    }
}

# ============================================================================
# Export Module Members
# ============================================================================
Export-ModuleMember -Function @(
    'Clear-NpmCache'
    'Clear-PythonCache'
    'Clear-GoCache'
    'Clear-RustCache'
    'Clear-DockerCache'
    'Clear-JvmCache'
    'Clear-FrontendCache'
    'Clear-CloudToolsCache'
    'Clear-IdeCache'
    'Clear-OtherLangCache'
    'Clear-MLModelCache'
    'Clear-StaleNodeModules'
    'Invoke-DevCleanup'
)
