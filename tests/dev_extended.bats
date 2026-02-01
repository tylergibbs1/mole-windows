#!/usr/bin/env bats

setup_file() {
    PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    export PROJECT_ROOT

    ORIGINAL_HOME="${HOME:-}"
    export ORIGINAL_HOME

    HOME="$(mktemp -d "${BATS_TEST_DIRNAME}/tmp-dev-extended.XXXXXX")"
    export HOME

    mkdir -p "$HOME"
}

teardown_file() {
    rm -rf "$HOME"
    if [[ -n "${ORIGINAL_HOME:-}" ]]; then
        export HOME="$ORIGINAL_HOME"
    fi
}

@test "clean_dev_elixir cleans hex cache" {
    mkdir -p "$HOME/.mix" "$HOME/.hex"
    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/common.sh"
source "$PROJECT_ROOT/lib/clean/dev.sh"
safe_clean() { echo "$2"; }
clean_dev_elixir
EOF

    [ "$status" -eq 0 ]
    [[ "$output" == *"Hex cache"* ]]
}

@test "clean_dev_elixir does not clean mix archives" {
    mkdir -p "$HOME/.mix/archives"
    touch "$HOME/.mix/archives/test_tool.ez"

    # Source and run the function
    source "$PROJECT_ROOT/lib/core/common.sh"
    source "$PROJECT_ROOT/lib/clean/dev.sh"
    # shellcheck disable=SC2329
    safe_clean() { :; }
    clean_dev_elixir > /dev/null 2>&1 || true

    # Verify the file still exists
    [ -f "$HOME/.mix/archives/test_tool.ez" ]
}

@test "clean_dev_haskell cleans cabal install cache" {
    mkdir -p "$HOME/.cabal" "$HOME/.stack"
    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/common.sh"
source "$PROJECT_ROOT/lib/clean/dev.sh"
safe_clean() { echo "$2"; }
clean_dev_haskell
EOF

    [ "$status" -eq 0 ]
    [[ "$output" == *"Cabal install cache"* ]]
}

@test "clean_dev_haskell does not clean stack programs" {
    mkdir -p "$HOME/.stack/programs/x86_64-osx"
    touch "$HOME/.stack/programs/x86_64-osx/ghc-9.2.8.tar.xz"

    # Source and run the function
    source "$PROJECT_ROOT/lib/core/common.sh"
    source "$PROJECT_ROOT/lib/clean/dev.sh"
    # shellcheck disable=SC2329
    safe_clean() { :; }
    clean_dev_haskell > /dev/null 2>&1 || true

    # Verify the file still exists
    [ -f "$HOME/.stack/programs/x86_64-osx/ghc-9.2.8.tar.xz" ]
}

@test "clean_dev_ocaml cleans opam cache" {
    mkdir -p "$HOME/.opam"
    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/common.sh"
source "$PROJECT_ROOT/lib/clean/dev.sh"
safe_clean() { echo "$2"; }
clean_dev_ocaml
EOF

    [ "$status" -eq 0 ]
    [[ "$output" == *"Opam cache"* ]]
}

@test "clean_dev_editors cleans VS Code and Zed caches" {
    mkdir -p "$HOME/Library/Caches/com.microsoft.VSCode" "$HOME/Library/Application Support/Code" "$HOME/Library/Caches/Zed"
    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/common.sh"
source "$PROJECT_ROOT/lib/clean/dev.sh"
safe_clean() { echo "$2"; }
clean_dev_editors
EOF

    [ "$status" -eq 0 ]
    [[ "$output" == *"VS Code cached data"* ]]
    [[ "$output" == *"Zed cache"* ]]
}

@test "clean_dev_editors does not clean VS Code workspace storage" {
    mkdir -p "$HOME/Library/Application Support/Code/User/workspaceStorage/abc123"
    touch "$HOME/Library/Application Support/Code/User/workspaceStorage/abc123/workspace.json"

    # Source and run the function
    source "$PROJECT_ROOT/lib/core/common.sh"
    source "$PROJECT_ROOT/lib/clean/dev.sh"
    # shellcheck disable=SC2329
    safe_clean() { :; }
    clean_dev_editors > /dev/null 2>&1 || true

    # Verify the file still exists
    [ -f "$HOME/Library/Application Support/Code/User/workspaceStorage/abc123/workspace.json" ]
}

@test "check_android_ndk reports multiple NDK versions" {
    run bash -c 'HOME=$(mktemp -d) && mkdir -p "$HOME/Library/Android/sdk/ndk"/{21.0.1,22.0.0,20.0.0} && source "$0" && note_activity() { :; } && NC="" && GREEN="" && GRAY="" && YELLOW="" && ICON_SUCCESS="✓" && check_android_ndk' "$PROJECT_ROOT/lib/clean/dev.sh"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Android NDK versions: 3 found"* ]]
}

@test "check_android_ndk silent when only one NDK" {
    run bash -c 'HOME=$(mktemp -d) && mkdir -p "$HOME/Library/Android/sdk/ndk/22.0.0" && source "$0" && note_activity() { :; } && NC="" && GREEN="" && GRAY="" && YELLOW="" && ICON_SUCCESS="✓" && check_android_ndk' "$PROJECT_ROOT/lib/clean/dev.sh"

    [ "$status" -eq 0 ]
    [[ "$output" != *"NDK versions"* ]]
}

@test "check_rust_toolchains reports multiple toolchains" {
    run bash -c 'HOME=$(mktemp -d) && mkdir -p "$HOME/.rustup/toolchains"/{stable,nightly,1.75.0}-aarch64-apple-darwin && source "$0" && note_activity() { :; } && NC="" && GREEN="" && GRAY="" && YELLOW="" && ICON_SUCCESS="✓" && rustup() { :; } && export -f rustup && check_rust_toolchains' "$PROJECT_ROOT/lib/clean/dev.sh"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Rust toolchains: 3 found"* ]]
}

@test "check_rust_toolchains silent when only one toolchain" {
    run bash -c 'HOME=$(mktemp -d) && mkdir -p "$HOME/.rustup/toolchains/stable-aarch64-apple-darwin" && source "$0" && note_activity() { :; } && NC="" && GREEN="" && GRAY="" && YELLOW="" && ICON_SUCCESS="✓" && rustup() { :; } && export -f rustup && check_rust_toolchains' "$PROJECT_ROOT/lib/clean/dev.sh"

    [ "$status" -eq 0 ]
    [[ "$output" != *"Rust toolchains"* ]]
}

@test "clean_dev_jetbrains_toolbox cleans old versions and bypasses toolbox whitelist" {
    local toolbox_channel="$HOME/Library/Application Support/JetBrains/Toolbox/apps/IDEA/ch-0"
    mkdir -p "$toolbox_channel/241.1" "$toolbox_channel/241.2" "$toolbox_channel/241.3"
    ln -s "241.3" "$toolbox_channel/current"
    touch -t 202401010000 "$toolbox_channel/241.1"
    touch -t 202402010000 "$toolbox_channel/241.2"
    touch -t 202403010000 "$toolbox_channel/241.3"

    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/common.sh"
source "$PROJECT_ROOT/lib/clean/dev.sh"
toolbox_root="$HOME/Library/Application Support/JetBrains/Toolbox/apps"
WHITELIST_PATTERNS=("$toolbox_root"* "$HOME/Library/Application Support/JetBrains*")
note_activity() { :; }
safe_clean() {
    local target="$1"
    for pattern in "${WHITELIST_PATTERNS[@]+${WHITELIST_PATTERNS[@]}}"; do
        if [[ "$pattern" == "$toolbox_root"* ]]; then
            echo "WHITELIST_NOT_REMOVED"
            exit 1
        fi
    done
    echo "$target"
}
MOLE_JETBRAINS_TOOLBOX_KEEP=1
clean_dev_jetbrains_toolbox
EOF

    [ "$status" -eq 0 ]
    [[ "$output" == *"/241.1"* ]]
    [[ "$output" != *"/241.2"* ]]
}

@test "clean_dev_jetbrains_toolbox keeps current directory and removes older versions" {
    local toolbox_channel="$HOME/Library/Application Support/JetBrains/Toolbox/apps/IDEA/ch-0"
    mkdir -p "$toolbox_channel/241.1" "$toolbox_channel/241.2" "$toolbox_channel/current"
    touch -t 202401010000 "$toolbox_channel/241.1"
    touch -t 202402010000 "$toolbox_channel/241.2"

    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/common.sh"
source "$PROJECT_ROOT/lib/clean/dev.sh"
note_activity() { :; }
safe_clean() { echo "$1"; }
MOLE_JETBRAINS_TOOLBOX_KEEP=1
clean_dev_jetbrains_toolbox
EOF

    [ "$status" -eq 0 ]
    [[ "$output" == *"/241.1"* ]]
    [[ "$output" != *"/241.2"* ]]
}
