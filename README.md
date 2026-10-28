<div align="center">
  <h1>Mole for Windows</h1>
  <p><em>Deep clean and optimize your Windows PC.</em></p>
</div>

<p align="center">
  <a href="https://github.com/tylergibbs1/mole-windows/stargazers"><img src="https://img.shields.io/github/stars/tylergibbs1/mole-windows?style=flat-square" alt="Stars"></a>
  <a href="https://github.com/tylergibbs1/mole-windows/actions/workflows/build.yml"><img src="https://img.shields.io/github/actions/workflow/status/tylergibbs1/mole-windows/build.yml?branch=main&style=flat-square&label=build" alt="Build"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square" alt="License"></a>
</p>

Windows port of [Mole](https://github.com/tw93/Mole) by [Tw93](https://github.com/tw93).

## Quick Start

Clone and preview a cleanup in PowerShell:

```powershell
git clone https://github.com/tylergibbs1/mole-windows.git
cd mole-windows/windows
.\mole.ps1 clean -DryRun  # Preview first
```

Or install to PATH:

```powershell
cd mole-windows/windows
.\install.ps1
# Then use from anywhere:
mole clean
```

Requires Windows 10/11 and PowerShell 5.1 or later. Administrator privileges are needed for full system cleanup.

## Features

- **Deep cleaning**: Scans and removes caches, temp files, and browser leftovers to **reclaim gigabytes of space**
- **Developer tools**: Cleans npm, pip, cargo, go, gradle, yarn, bun, conda, poetry, and more
- **Browser cleanup**: Chrome, Edge, Firefox, and Brave cache cleanup
- **Windows-specific**: Prefetch, font cache, Windows Error Reports, DNS cache, thumbnail cache
- **Disk tools**: a visual disk explorer and live system health dashboard (Go TUIs), plus duplicate, large-file, and media finders
- **Safe by design**: 4-layer path validation, dry-run mode, whitelist system

## Usage

```powershell
mole                         # Show help
mole clean                   # Deep cleanup
mole clean -DryRun           # Preview what would be cleaned (alias: -n)
mole clean -Quick            # Temp, browser, and Recycle Bin only (alias: -q)
mole clean -Select           # Pick items to clean interactively (alias: -s)
mole clean -Admin            # Run as admin for full cleanup
mole clean -Drive D          # Show free space for D: drive

mole analyze                 # Visual disk explorer (Go TUI)
mole status                  # Live system health dashboard (Go TUI)
mole purge                   # Clean project build artifacts
mole optimize                # Refresh caches & services

mole dupes C:                # Find duplicate files (--min 10MB to filter)
mole large C:                # Find files over 100MB (--min 1GB to change)
mole media scan C:           # Find videos and images
mole media transfer C: E:    # Move media between drives (-n to preview)

mole whitelist show          # View protected paths
mole whitelist add <path>    # Protect a path from cleanup
mole whitelist remove <path> # Remove path from whitelist

mole version                 # Show version
mole help                    # Show help
```

Other `clean` options: `-Yes` skips confirmation prompts; `-NoBrowser`, `-NoDev`, and `-NoRecycleBin` skip those categories.

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

Preview any cleanup with `-DryRun`:

```powershell
mole clean -DryRun
```

## Configuration and Debugging

Config lives in `%LOCALAPPDATA%\mole`, including the `whitelist` file and `mole.log`.

For detailed logs, pass `-DebugMode` (alias `-d`) or set the environment variable:

```powershell
$env:MOLE_DEBUG = "1"
mole clean -DryRun
```

Debug log saved to: `%LOCALAPPDATA%\mole\mole_debug_session.log`

## Development

The `analyze` and `status` TUIs are Go programs in `cmd/`:

```bash
make build      # builds bin/analyze.exe and bin/status.exe
go test ./...
```

CI (`.github/workflows/build.yml`) builds both binaries and runs the Go tests on Windows.

## License

[MIT](LICENSE)
