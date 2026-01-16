<div align="center">
  <h1>Mole for Windows</h1>
  <p><em>Deep clean and optimize your Windows PC.</em></p>
</div>

<p align="center">
  <a href="https://github.com/Tylerbryy/mole-windows/stargazers"><img src="https://img.shields.io/github/stars/Tylerbryy/mole-windows?style=flat-square" alt="Stars"></a>
  <a href="https://github.com/Tylerbryy/mole-windows/releases"><img src="https://img.shields.io/github/v/tag/Tylerbryy/mole-windows?label=version&style=flat-square" alt="Version"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square" alt="License"></a>
</p>

## Features

- **Deep cleaning**: Scans and removes caches, temp files, and browser leftovers to **reclaim gigabytes of space**
- **Developer tools**: Cleans npm, pip, cargo, go, gradle, yarn, bun, conda, poetry, and more
- **Browser cleanup**: Chrome, Edge, Firefox, and Brave cache cleanup
- **Windows-specific**: Prefetch, font cache, Windows Error Reports, DNS cache, thumbnail cache
- **Safe by design**: 4-layer path validation, dry-run mode, whitelist system

## Quick Start

**Install via PowerShell:**

```powershell
# Clone and run
git clone https://github.com/Tylerbryy/mole-windows.git
cd mole-windows/windows
.\mole.ps1 clean --dry-run  # Preview first
```

**Or install to PATH:**

```powershell
cd mole-windows/windows
.\install.ps1
# Then use from anywhere:
mole clean
```

## Usage

```powershell
mole                         # Show help
mole clean                   # Deep cleanup
mole clean --dry-run         # Preview what would be cleaned
mole clean --admin           # Run as admin for full cleanup
mole clean -Drive D          # Show free space for D: drive

mole analyze                 # Visual disk explorer (Go TUI)
mole status                  # Live system health dashboard (Go TUI)
mole purge                   # Clean project build artifacts
mole optimize                # Refresh caches & services

mole whitelist show          # View protected paths
mole whitelist add <path>    # Protect a path from cleanup
mole whitelist remove <path> # Remove path from whitelist

mole version                 # Show version
mole help                    # Show help
```

## What Gets Cleaned

### User Data
- User temp files (`%TEMP%`)
- Recycle Bin
- Recent files list
- Thumbnail and icon caches
- Windows Search cache
- Crash dumps and error reports
- Installer caches
- Font cache

### Browsers
- Google Chrome cache
- Microsoft Edge cache
- Mozilla Firefox cache
- Brave Browser cache

### Developer Tools
| Tool | Cache Location |
|------|---------------|
| npm | `%LOCALAPPDATA%\npm-cache` |
| pnpm | pnpm store |
| Yarn | `%LOCALAPPDATA%\Yarn\Cache` |
| Bun | `%USERPROFILE%\.bun` |
| pip | `%LOCALAPPDATA%\pip\Cache` |
| Poetry | `%LOCALAPPDATA%\pypoetry` |
| uv | `%LOCALAPPDATA%\uv` |
| Conda | `%USERPROFILE%\anaconda3\pkgs` |
| Go | `%LOCALAPPDATA%\go-build` |
| Cargo | `%USERPROFILE%\.cargo\registry\cache` |
| Gradle | `%USERPROFILE%\.gradle\caches` |
| Maven | `%USERPROFILE%\.m2\repository` |
| Docker | Docker build cache |
| node-gyp | `%LOCALAPPDATA%\node-gyp` |
| Electron | `%LOCALAPPDATA%\electron` |

### Windows System (requires admin)
- Windows Update cache
- System temp files
- Prefetch files
- System font cache
- Delivery Optimization cache
- Windows Error Reports

## Safety Features

Mole uses the same 4-layer protection as the macOS version:

1. **Path validation**: Empty paths, path traversal (`..`), and invalid paths blocked
2. **Critical path protection**: System32, Program Files, Windows folder protected
3. **BOM whitelist**: User-configurable protected paths
4. **Pattern matching**: 500+ protected app data patterns

Preview any cleanup with `--dry-run`:

```powershell
mole clean --dry-run
```

## Debug Mode

For detailed logs:

```powershell
$env:MOLE_DEBUG = "1"
mole clean --dry-run
```

Debug log saved to: `%LOCALAPPDATA%\mole\mole_debug_session.log`

## Requirements

- Windows 10/11
- PowerShell 5.1 or later
- Administrator privileges for full system cleanup

## Credits

Windows port of [Mole](https://github.com/tw93/Mole) by [Tw93](https://github.com/tw93).

## License

MIT License
