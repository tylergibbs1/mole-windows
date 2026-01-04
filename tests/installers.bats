#!/usr/bin/env bats

setup_file() {
    PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    export PROJECT_ROOT

    ORIGINAL_HOME="${HOME:-}"
    export ORIGINAL_HOME

    HOME="$(mktemp -d "${BATS_TEST_DIRNAME}/tmp-installers-home.XXXXXX")"
    export HOME

    mkdir -p "$HOME"
}

teardown_file() {
    rm -rf "$HOME"
    if [[ -n "${ORIGINAL_HOME:-}" ]]; then
        export HOME="$ORIGINAL_HOME"
    fi
}

setup() {
    export TERM="xterm-256color"
    export MO_DEBUG=0

    # Create standard scan directories
    mkdir -p "$HOME/Downloads"
    mkdir -p "$HOME/Desktop"
    mkdir -p "$HOME/Documents"
    mkdir -p "$HOME/Public"
    mkdir -p "$HOME/Library/Downloads"

    # Clear previous test files
    rm -rf "${HOME:?}/Downloads"/*
    rm -rf "${HOME:?}/Desktop"/*
    rm -rf "${HOME:?}/Documents"/*
}

# Test help and arguments

@test "installers.sh --help shows usage information" {
    run "$PROJECT_ROOT/bin/installers.sh" --help

    [ "$status" -eq 0 ]
    [[ "$output" == *"Mole Installers"* ]]
    [[ "$output" == *"Usage:"* ]]
    [[ "$output" == *"mo installers"* ]]
}

@test "installers.sh --help lists options and paths" {
    run "$PROJECT_ROOT/bin/installers.sh" --help

    [ "$status" -eq 0 ]
    [[ "$output" == *"--debug"* ]]
    [[ "$output" == *"--help"* ]]
    [[ "$output" == *"mo installers"* ]]
}

@test "installers.sh --help shows scan scope" {
    run "$PROJECT_ROOT/bin/installers.sh" --help

    [ "$status" -eq 0 ]
    [[ "$output" == *"Downloads"* ]]
    [[ "$output" == *"Desktop"* ]]
    [[ "$output" == *"Documents"* ]]
}

@test "installers.sh rejects unknown options" {
    run "$PROJECT_ROOT/bin/installers.sh" --unknown-option

    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown option"* ]]
    [[ "$output" == *"--help"* ]]
}

# Test scan_installers_in_path function directly
# Tests are duplicated to cover both fd and find code paths

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Tests using fd (when available)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

@test "scan_installers_in_path (fd): finds .dmg files" {
    if ! command -v fd > /dev/null 2>&1; then
        skip "fd not available on this system"
    fi

    touch "$HOME/Downloads/Chrome.dmg"

    run bash -euo pipefail -c '
        export MOLE_TEST_MODE=1
        source "$1"
        scan_installers_in_path "$2"
    ' bash "$PROJECT_ROOT/bin/installers.sh" "$HOME/Downloads"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Chrome.dmg"* ]]
}

@test "scan_installers_in_path (fd): finds multiple installer types" {
    if ! command -v fd > /dev/null 2>&1; then
        skip "fd not available on this system"
    fi

    touch "$HOME/Downloads/App1.dmg"
    touch "$HOME/Downloads/App2.pkg"
    touch "$HOME/Downloads/App3.iso"
    touch "$HOME/Downloads/App.mpkg"

    run bash -euo pipefail -c '
        export MOLE_TEST_MODE=1
        source "$1"
        scan_installers_in_path "$2"
    ' bash "$PROJECT_ROOT/bin/installers.sh" "$HOME/Downloads"

    [ "$status" -eq 0 ]
    [[ "$output" == *"App1.dmg"* ]]
    [[ "$output" == *"App2.pkg"* ]]
    [[ "$output" == *"App3.iso"* ]]
    [[ "$output" == *"App.mpkg"* ]]
}

@test "scan_installers_in_path (fd): respects max depth" {
    if ! command -v fd > /dev/null 2>&1; then
        skip "fd not available on this system"
    fi

    mkdir -p "$HOME/Downloads/level1/level2/level3"
    touch "$HOME/Downloads/shallow.dmg"
    touch "$HOME/Downloads/level1/mid.dmg"
    touch "$HOME/Downloads/level1/level2/deep.dmg"
    touch "$HOME/Downloads/level1/level2/level3/too-deep.dmg"

    run bash -euo pipefail -c '
        export MOLE_TEST_MODE=1
        source "$1"
        scan_installers_in_path "$2"
    ' bash "$PROJECT_ROOT/bin/installers.sh" "$HOME/Downloads"

    [ "$status" -eq 0 ]
    # Default max depth is 2
    [[ "$output" == *"shallow.dmg"* ]]
    [[ "$output" == *"mid.dmg"* ]]
    [[ "$output" == *"deep.dmg"* ]]
    [[ "$output" != *"too-deep.dmg"* ]]
}

@test "scan_installers_in_path (fd): honors MOLE_INSTALLER_SCAN_MAX_DEPTH" {
    if ! command -v fd > /dev/null 2>&1; then
        skip "fd not available on this system"
    fi

    mkdir -p "$HOME/Downloads/level1"
    touch "$HOME/Downloads/top.dmg"
    touch "$HOME/Downloads/level1/nested.dmg"

    run env MOLE_INSTALLER_SCAN_MAX_DEPTH=1 bash -euo pipefail -c "
        export MOLE_TEST_MODE=1
        source \"\$1\"
        scan_installers_in_path \"\$2\"
    " bash "$PROJECT_ROOT/bin/installers.sh" "$HOME/Downloads"

    [ "$status" -eq 0 ]
    [[ "$output" == *"top.dmg"* ]]
    [[ "$output" != *"nested.dmg"* ]]
}

@test "scan_installers_in_path (fd): handles non-existent directory" {
    if ! command -v fd > /dev/null 2>&1; then
        skip "fd not available on this system"
    fi

    run bash -euo pipefail -c '
        export MOLE_TEST_MODE=1
        source "$1"
        scan_installers_in_path "$2"
    ' bash "$PROJECT_ROOT/bin/installers.sh" "$HOME/NonExistent"

    [ "$status" -eq 0 ]
    [[ -z "$output" ]]
}

@test "scan_installers_in_path (fd): ignores non-installer files" {
    if ! command -v fd > /dev/null 2>&1; then
        skip "fd not available on this system"
    fi

    touch "$HOME/Downloads/document.pdf"
    touch "$HOME/Downloads/image.jpg"
    touch "$HOME/Downloads/archive.tar.gz"
    touch "$HOME/Downloads/Installer.dmg"

    run bash -euo pipefail -c '
        export MOLE_TEST_MODE=1
        source "$1"
        scan_installers_in_path "$2"
    ' bash "$PROJECT_ROOT/bin/installers.sh" "$HOME/Downloads"

    [ "$status" -eq 0 ]
    [[ "$output" != *"document.pdf"* ]]
    [[ "$output" != *"image.jpg"* ]]
    [[ "$output" != *"archive.tar.gz"* ]]
    [[ "$output" == *"Installer.dmg"* ]]
}

@test "scan_installers_in_path (fd): handles filenames with spaces" {
    if ! command -v fd > /dev/null 2>&1; then
        skip "fd not available on this system"
    fi

    touch "$HOME/Downloads/My App Installer.dmg"

    run bash -euo pipefail -c '
        export MOLE_TEST_MODE=1
        source "$1"
        scan_installers_in_path "$2"
    ' bash "$PROJECT_ROOT/bin/installers.sh" "$HOME/Downloads"

    [ "$status" -eq 0 ]
    [[ "$output" == *"My App Installer.dmg"* ]]
}

@test "scan_installers_in_path (fd): handles filenames with special characters" {
    if ! command -v fd > /dev/null 2>&1; then
        skip "fd not available on this system"
    fi

    touch "$HOME/Downloads/App-v1.2.3_beta.pkg"

    run bash -euo pipefail -c '
        export MOLE_TEST_MODE=1
        source "$1"
        scan_installers_in_path "$2"
    ' bash "$PROJECT_ROOT/bin/installers.sh" "$HOME/Downloads"

    [ "$status" -eq 0 ]
    [[ "$output" == *"App-v1.2.3_beta.pkg"* ]]
}

@test "scan_installers_in_path (fd): returns empty for directory with no installers" {
    if ! command -v fd > /dev/null 2>&1; then
        skip "fd not available on this system"
    fi

    # Create some non-installer files
    touch "$HOME/Downloads/document.pdf"
    touch "$HOME/Downloads/image.png"

    run bash -euo pipefail -c '
        export MOLE_TEST_MODE=1
        source "$1"
        scan_installers_in_path "$2"
    ' bash "$PROJECT_ROOT/bin/installers.sh" "$HOME/Downloads"

    [ "$status" -eq 0 ]
    [[ -z "$output" ]]
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Tests using find (forced fallback by hiding fd)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

@test "scan_installers_in_path (fallback find): finds .dmg files" {
    touch "$HOME/Downloads/Chrome.dmg"

    run env PATH="/usr/bin:/bin" bash -euo pipefail -c "
        export MOLE_TEST_MODE=1
        source \"\$1\"
        scan_installers_in_path \"\$2\"
    " bash "$PROJECT_ROOT/bin/installers.sh" "$HOME/Downloads"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Chrome.dmg"* ]]
}

@test "scan_installers_in_path (fallback find): finds multiple installer types" {
    touch "$HOME/Downloads/App1.dmg"
    touch "$HOME/Downloads/App2.pkg"
    touch "$HOME/Downloads/App3.iso"
    touch "$HOME/Downloads/App.mpkg"

    run env PATH="/usr/bin:/bin" bash -euo pipefail -c "
        export MOLE_TEST_MODE=1
        source \"\$1\"
        scan_installers_in_path \"\$2\"
    " bash "$PROJECT_ROOT/bin/installers.sh" "$HOME/Downloads"

    [ "$status" -eq 0 ]
    [[ "$output" == *"App1.dmg"* ]]
    [[ "$output" == *"App2.pkg"* ]]
    [[ "$output" == *"App3.iso"* ]]
    [[ "$output" == *"App.mpkg"* ]]
}

@test "scan_installers_in_path (fallback find): respects max depth" {
    mkdir -p "$HOME/Downloads/level1/level2/level3"
    touch "$HOME/Downloads/shallow.dmg"
    touch "$HOME/Downloads/level1/mid.dmg"
    touch "$HOME/Downloads/level1/level2/deep.dmg"
    touch "$HOME/Downloads/level1/level2/level3/too-deep.dmg"

    run env PATH="/usr/bin:/bin" bash -euo pipefail -c "
        export MOLE_TEST_MODE=1
        source \"\$1\"
        scan_installers_in_path \"\$2\"
    " bash "$PROJECT_ROOT/bin/installers.sh" "$HOME/Downloads"

    [ "$status" -eq 0 ]
    # Default max depth is 2
    [[ "$output" == *"shallow.dmg"* ]]
    [[ "$output" == *"mid.dmg"* ]]
    [[ "$output" == *"deep.dmg"* ]]
    [[ "$output" != *"too-deep.dmg"* ]]
}

@test "scan_installers_in_path (fallback find): honors MOLE_INSTALLER_SCAN_MAX_DEPTH" {
    mkdir -p "$HOME/Downloads/level1"
    touch "$HOME/Downloads/top.dmg"
    touch "$HOME/Downloads/level1/nested.dmg"

    run env PATH="/usr/bin:/bin" MOLE_INSTALLER_SCAN_MAX_DEPTH=1 bash -euo pipefail -c "
        export MOLE_TEST_MODE=1
        source \"\$1\"
        scan_installers_in_path \"\$2\"
    " bash "$PROJECT_ROOT/bin/installers.sh" "$HOME/Downloads"

    [ "$status" -eq 0 ]
    [[ "$output" == *"top.dmg"* ]]
    [[ "$output" != *"nested.dmg"* ]]
}

@test "scan_installers_in_path (fallback find): handles non-existent directory" {
    run env PATH="/usr/bin:/bin" bash -euo pipefail -c "
        export MOLE_TEST_MODE=1
        source \"\$1\"
        scan_installers_in_path \"\$2\"
    " bash "$PROJECT_ROOT/bin/installers.sh" "$HOME/NonExistent"

    [ "$status" -eq 0 ]
    [[ -z "$output" ]]
}

@test "scan_installers_in_path (fallback find): ignores non-installer files" {
    touch "$HOME/Downloads/document.pdf"
    touch "$HOME/Downloads/image.jpg"
    touch "$HOME/Downloads/archive.tar.gz"
    touch "$HOME/Downloads/Installer.dmg"

    run env PATH="/usr/bin:/bin" bash -euo pipefail -c "
        export MOLE_TEST_MODE=1
        source \"\$1\"
        scan_installers_in_path \"\$2\"
    " bash "$PROJECT_ROOT/bin/installers.sh" "$HOME/Downloads"

    [ "$status" -eq 0 ]
    [[ "$output" != *"document.pdf"* ]]
    [[ "$output" != *"image.jpg"* ]]
    [[ "$output" != *"archive.tar.gz"* ]]
    [[ "$output" == *"Installer.dmg"* ]]
}

# Test ZIP installer detection

@test "is_installer_zip: rejects ZIP with installer content but too many entries" {
    if ! command -v zipinfo > /dev/null 2>&1; then
        skip "zipinfo not available"
    fi

    # Create a ZIP with too many files (exceeds MAX_ZIP_ENTRIES=5)
    # Include a .app file to have installer content
    mkdir -p "$HOME/Downloads/large-app"
    touch "$HOME/Downloads/large-app/MyApp.app"
    for i in {1..9}; do
        touch "$HOME/Downloads/large-app/file$i.txt"
    done
    (cd "$HOME/Downloads" && zip -q -r large-installer.zip large-app)

    run bash -euo pipefail -c '
        export MOLE_TEST_MODE=1
        source "$1"
        if is_installer_zip "'"$HOME/Downloads/large-installer.zip"'"; then
            echo "INSTALLER"
        else
            echo "NOT_INSTALLER"
        fi
    ' bash "$PROJECT_ROOT/bin/installers.sh"

    [ "$status" -eq 0 ]
    [[ "$output" == "NOT_INSTALLER" ]]
}

@test "is_installer_zip: detects ZIP with app content" {
    if ! command -v zipinfo > /dev/null 2>&1; then
        skip "zipinfo not available"
    fi

    mkdir -p "$HOME/Downloads/app-content"
    touch "$HOME/Downloads/app-content/MyApp.app"
    (cd "$HOME/Downloads" && zip -q -r app.zip app-content)

    run bash -euo pipefail -c '
        export MOLE_TEST_MODE=1
        source "$1"
        if is_installer_zip "'"$HOME/Downloads/app.zip"'"; then
            echo "INSTALLER"
        else
            echo "NOT_INSTALLER"
        fi
    ' bash "$PROJECT_ROOT/bin/installers.sh"

    [ "$status" -eq 0 ]
    [[ "$output" == "INSTALLER" ]]
}

@test "is_installer_zip: rejects ZIP with only regular files" {
    if ! command -v zipinfo > /dev/null 2>&1; then
        skip "zipinfo not available"
    fi

    mkdir -p "$HOME/Downloads/data"
    touch "$HOME/Downloads/data/file1.txt"
    touch "$HOME/Downloads/data/file2.pdf"
    (cd "$HOME/Downloads" && zip -q -r data.zip data)

    run bash -euo pipefail -c '
        export MOLE_TEST_MODE=1
        source "$1"
        if is_installer_zip "'"$HOME/Downloads/data.zip"'"; then
            echo "INSTALLER"
        else
            echo "NOT_INSTALLER"
        fi
    ' bash "$PROJECT_ROOT/bin/installers.sh"

    [ "$status" -eq 0 ]
    [[ "$output" == "NOT_INSTALLER" ]]
}

# Integration tests: ZIP scanning inside scan_all_installers

@test "scan_all_installers: finds installer ZIP in Downloads" {
    if ! command -v zipinfo > /dev/null 2>&1; then
        skip "zipinfo not available"
    fi

    # Create a valid installer ZIP (contains .app)
    mkdir -p "$HOME/Downloads/app-content"
    touch "$HOME/Downloads/app-content/MyApp.app"
    (cd "$HOME/Downloads" && zip -q -r installer.zip app-content)

    run bash -euo pipefail -c '
        export MOLE_TEST_MODE=1
        source "$1"
        scan_all_installers
    ' bash "$PROJECT_ROOT/bin/installers.sh"

    [ "$status" -eq 0 ]
    [[ "$output" == *"installer.zip"* ]]
}

@test "scan_all_installers: ignores non-installer ZIP in Downloads" {
    if ! command -v zipinfo > /dev/null 2>&1; then
        skip "zipinfo not available"
    fi

    # Create a non-installer ZIP (only regular files)
    mkdir -p "$HOME/Downloads/data"
    touch "$HOME/Downloads/data/file1.txt"
    touch "$HOME/Downloads/data/file2.pdf"
    (cd "$HOME/Downloads" && zip -q -r data.zip data)

    run bash -euo pipefail -c '
        export MOLE_TEST_MODE=1
        source "$1"
        scan_all_installers
    ' bash "$PROJECT_ROOT/bin/installers.sh"

    [ "$status" -eq 0 ]
    [[ "$output" != *"data.zip"* ]]
}

@test "scan_all_installers: handles missing paths gracefully" {
    # Don't create all scan directories, some may not exist
    # Only create Downloads, delete others if they exist
    rm -rf "$HOME/Desktop"
    rm -rf "$HOME/Documents"
    rm -rf "$HOME/Public"
    rm -rf "$HOME/Public/Downloads"
    rm -rf "$HOME/Library/Downloads"
    mkdir -p "$HOME/Downloads"

    # Add an installer to the one directory that exists
    touch "$HOME/Downloads/test.dmg"

    run bash -euo pipefail -c '
        export MOLE_TEST_MODE=1
        source "$1"
        scan_all_installers
    ' bash "$PROJECT_ROOT/bin/installers.sh"

    # Should succeed even with missing paths
    [ "$status" -eq 0 ]
    # Should still find the installer in the existing directory
    [[ "$output" == *"test.dmg"* ]]
}

# Test edge cases

@test "scan_installers_in_path (fallback find): handles filenames with spaces" {
    touch "$HOME/Downloads/My App Installer.dmg"

    run env PATH="/usr/bin:/bin" bash -euo pipefail -c "
        export MOLE_TEST_MODE=1
        source \"\$1\"
        scan_installers_in_path \"\$2\"
    " bash "$PROJECT_ROOT/bin/installers.sh" "$HOME/Downloads"

    [ "$status" -eq 0 ]
    [[ "$output" == *"My App Installer.dmg"* ]]
}

@test "scan_installers_in_path (fallback find): handles filenames with special characters" {
    touch "$HOME/Downloads/App-v1.2.3_beta.pkg"

    run env PATH="/usr/bin:/bin" bash -euo pipefail -c "
        export MOLE_TEST_MODE=1
        source \"\$1\"
        scan_installers_in_path \"\$2\"
    " bash "$PROJECT_ROOT/bin/installers.sh" "$HOME/Downloads"

    [ "$status" -eq 0 ]
    [[ "$output" == *"App-v1.2.3_beta.pkg"* ]]
}

@test "scan_installers_in_path (fallback find): returns empty for directory with no installers" {
    # Create some non-installer files
    touch "$HOME/Downloads/document.pdf"
    touch "$HOME/Downloads/image.png"

    run env PATH="/usr/bin:/bin" bash -euo pipefail -c "
        export MOLE_TEST_MODE=1
        source \"\$1\"
        scan_installers_in_path \"\$2\"
    " bash "$PROJECT_ROOT/bin/installers.sh" "$HOME/Downloads"

    [ "$status" -eq 0 ]
    [[ -z "$output" ]]
}

# Failure path tests for scan_installers_in_path

@test "scan_installers_in_path: skips corrupt ZIP files" {
    if ! command -v zipinfo > /dev/null 2>&1; then
        skip "zipinfo not available"
    fi

    # Create a corrupt ZIP file by just writing garbage data
    echo "This is not a valid ZIP file" > "$HOME/Downloads/corrupt.zip"

    run bash -euo pipefail -c '
        export MOLE_TEST_MODE=1
        source "$1"
        scan_installers_in_path "$2"
    ' bash "$PROJECT_ROOT/bin/installers.sh" "$HOME/Downloads"

    # Should succeed (return 0) and silently skip the corrupt ZIP
    [ "$status" -eq 0 ]
    # Output should be empty since corrupt.zip is not a valid installer
    [[ -z "$output" ]]
}

@test "scan_installers_in_path: handles permission-denied files" {
    if ! command -v zipinfo > /dev/null 2>&1; then
        skip "zipinfo not available"
    fi

    # Create a valid installer ZIP
    mkdir -p "$HOME/Downloads/app-content"
    touch "$HOME/Downloads/app-content/MyApp.app"
    (cd "$HOME/Downloads" && zip -q -r readable.zip app-content)

    # Create a readable installer ZIP alongside a permission-denied file
    mkdir -p "$HOME/Downloads/restricted-app"
    touch "$HOME/Downloads/restricted-app/App.app"
    (cd "$HOME/Downloads" && zip -q -r restricted.zip restricted-app)

    # Remove read permissions from restricted.zip
    chmod 000 "$HOME/Downloads/restricted.zip"

    run bash -euo pipefail -c '
        export MOLE_TEST_MODE=1
        source "$1"
        scan_installers_in_path "$2"
    ' bash "$PROJECT_ROOT/bin/installers.sh" "$HOME/Downloads"

    # Should succeed and find the readable.zip but skip restricted.zip
    [ "$status" -eq 0 ]
    [[ "$output" == *"readable.zip"* ]]
    [[ "$output" != *"restricted.zip"* ]]

    # Cleanup: restore permissions for teardown
    chmod 644 "$HOME/Downloads/restricted.zip"
}

@test "scan_installers_in_path: finds installer ZIP alongside corrupt ZIPs" {
    if ! command -v zipinfo > /dev/null 2>&1; then
        skip "zipinfo not available"
    fi

    # Create a valid installer ZIP
    mkdir -p "$HOME/Downloads/app-content"
    touch "$HOME/Downloads/app-content/MyApp.app"
    (cd "$HOME/Downloads" && zip -q -r valid-installer.zip app-content)

    # Create a corrupt ZIP
    echo "garbage data" > "$HOME/Downloads/corrupt.zip"

    run bash -euo pipefail -c '
        export MOLE_TEST_MODE=1
        source "$1"
        scan_installers_in_path "$2"
    ' bash "$PROJECT_ROOT/bin/installers.sh" "$HOME/Downloads"

    # Should find the valid ZIP and silently skip the corrupt one
    [ "$status" -eq 0 ]
    [[ "$output" == *"valid-installer.zip"* ]]
    [[ "$output" != *"corrupt.zip"* ]]
}

# Symlink handling tests

@test "scan_installers_in_path (fd): skips symlinks to regular files" {
    if ! command -v fd > /dev/null 2>&1; then
        skip "fd not available on this system"
    fi

    touch "$HOME/Downloads/real.dmg"
    ln -s "$HOME/Downloads/real.dmg" "$HOME/Downloads/symlink.dmg"
    ln -s /nonexistent "$HOME/Downloads/dangling.lnk"

    run bash -euo pipefail -c '
        export MOLE_TEST_MODE=1
        source "$1"
        scan_installers_in_path "$2"
    ' bash "$PROJECT_ROOT/bin/installers.sh" "$HOME/Downloads"

    [ "$status" -eq 0 ]
    [[ "$output" == *"real.dmg"* ]]
    [[ "$output" != *"symlink.dmg"* ]]
    [[ "$output" != *"dangling.lnk"* ]]
}

@test "scan_installers_in_path (fallback find): skips symlinks to regular files" {
    touch "$HOME/Downloads/real.dmg"
    ln -s "$HOME/Downloads/real.dmg" "$HOME/Downloads/symlink.dmg"
    ln -s /nonexistent "$HOME/Downloads/dangling.lnk"

    run env PATH="/usr/bin:/bin" bash -euo pipefail -c "
        export MOLE_TEST_MODE=1
        source \"\$1\"
        scan_installers_in_path \"\$2\"
    " bash "$PROJECT_ROOT/bin/installers.sh" "$HOME/Downloads"

    [ "$status" -eq 0 ]
    [[ "$output" == *"real.dmg"* ]]
    [[ "$output" != *"symlink.dmg"* ]]
    [[ "$output" != *"dangling.lnk"* ]]
}
