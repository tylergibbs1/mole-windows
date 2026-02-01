#!/usr/bin/env bats

setup_file() {
    PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    export PROJECT_ROOT

    ORIGINAL_HOME="${BATS_TMPDIR:-}" # Use BATS_TMPDIR as original HOME if set by bats
    if [[ -z "$ORIGINAL_HOME" ]]; then
        ORIGINAL_HOME="${HOME:-}"
    fi
    export ORIGINAL_HOME

    HOME="$(mktemp -d "${BATS_TEST_DIRNAME}/tmp-uninstall-home.XXXXXX")"
    export HOME
}

teardown_file() {
    rm -rf "$HOME"
    if [[ -n "${ORIGINAL_HOME:-}" ]]; then
        export HOME="$ORIGINAL_HOME"
    fi
}

setup() {
    export TERM="dumb"
    rm -rf "${HOME:?}"/*
    mkdir -p "$HOME"
}

create_app_artifacts() {
    mkdir -p "$HOME/Applications/TestApp.app"
    mkdir -p "$HOME/Library/Application Support/TestApp"
    mkdir -p "$HOME/Library/Caches/TestApp"
    mkdir -p "$HOME/Library/Containers/com.example.TestApp"
    mkdir -p "$HOME/Library/Preferences"
    touch "$HOME/Library/Preferences/com.example.TestApp.plist"
    mkdir -p "$HOME/Library/Preferences/ByHost"
    touch "$HOME/Library/Preferences/ByHost/com.example.TestApp.ABC123.plist"
    mkdir -p "$HOME/Library/Saved Application State/com.example.TestApp.savedState"
    mkdir -p "$HOME/Library/LaunchAgents"
    touch "$HOME/Library/LaunchAgents/com.example.TestApp.plist"
}

@test "find_app_files discovers user-level leftovers" {
    create_app_artifacts

    result="$(
        HOME="$HOME" bash --noprofile --norc << 'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/common.sh"
find_app_files "com.example.TestApp" "TestApp"
EOF
    )"

    [[ "$result" == *"Application Support/TestApp"* ]]
    [[ "$result" == *"Caches/TestApp"* ]]
    [[ "$result" == *"Preferences/com.example.TestApp.plist"* ]]
    [[ "$result" == *"Saved Application State/com.example.TestApp.savedState"* ]]
    [[ "$result" == *"Containers/com.example.TestApp"* ]]
    [[ "$result" == *"LaunchAgents/com.example.TestApp.plist"* ]]
}

@test "calculate_total_size returns aggregate kilobytes" {
    mkdir -p "$HOME/sized"
    dd if=/dev/zero of="$HOME/sized/file1" bs=1024 count=1 > /dev/null 2>&1
    dd if=/dev/zero of="$HOME/sized/file2" bs=1024 count=2 > /dev/null 2>&1

    result="$(
        HOME="$HOME" bash --noprofile --norc << 'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/common.sh"
files="$(printf '%s
%s
' "$HOME/sized/file1" "$HOME/sized/file2")"
calculate_total_size "$files"
EOF
    )"

    [ "$result" -ge 3 ]
}

@test "batch_uninstall_applications removes selected app data" {
    create_app_artifacts

    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" bash --noprofile --norc << 'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/common.sh"
source "$PROJECT_ROOT/lib/uninstall/batch.sh"

request_sudo_access() { return 0; }
start_inline_spinner() { :; }
stop_inline_spinner() { :; }
enter_alt_screen() { :; }
leave_alt_screen() { :; }
hide_cursor() { :; }
show_cursor() { :; }
remove_apps_from_dock() { :; }
pgrep() { return 1; }
pkill() { return 0; }
sudo() { return 0; } # Mock sudo command

app_bundle="$HOME/Applications/TestApp.app"
mkdir -p "$app_bundle" # Ensure this is created in the temp HOME

related="$(find_app_files "com.example.TestApp" "TestApp")"
encoded_related=$(printf '%s' "$related" | base64 | tr -d '\n')

selected_apps=()
selected_apps+=("0|$app_bundle|TestApp|com.example.TestApp|0|Never")
files_cleaned=0
total_items=0
total_size_cleaned=0

batch_uninstall_applications

[[ ! -d "$app_bundle" ]] || exit 1
[[ ! -d "$HOME/Library/Application Support/TestApp" ]] || exit 1
[[ ! -d "$HOME/Library/Caches/TestApp" ]] || exit 1
[[ ! -f "$HOME/Library/Preferences/com.example.TestApp.plist" ]] || exit 1
[[ ! -f "$HOME/Library/LaunchAgents/com.example.TestApp.plist" ]] || exit 1
EOF

    [ "$status" -eq 0 ]
}

@test "safe_remove can remove a simple directory" {
    mkdir -p "$HOME/test_dir"
    touch "$HOME/test_dir/file.txt"

    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" bash --noprofile --norc << 'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/common.sh"

safe_remove "$HOME/test_dir"
[[ ! -d "$HOME/test_dir" ]] || exit 1
EOF
    [ "$status" -eq 0 ]
}


@test "decode_file_list validates base64 encoding" {
    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" bash --noprofile --norc << 'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/common.sh"
source "$PROJECT_ROOT/lib/uninstall/batch.sh"

valid_data=$(printf '/path/one
/path/two' | base64)
result=$(decode_file_list "$valid_data" "TestApp")
[[ -n "$result" ]] || exit 1
EOF

    [ "$status" -eq 0 ]
}

@test "decode_file_list rejects invalid base64" {
    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" bash --noprofile --norc << 'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/common.sh"
source "$PROJECT_ROOT/lib/uninstall/batch.sh"

if result=$(decode_file_list "not-valid-base64!!!" "TestApp" 2>/dev/null); then
    [[ -z "$result" ]]
else
    true
fi
EOF

    [ "$status" -eq 0 ]
}

@test "decode_file_list handles empty input" {
    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" bash --noprofile --norc << 'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/common.sh"
source "$PROJECT_ROOT/lib/uninstall/batch.sh"

empty_data=$(printf '' | base64)
result=$(decode_file_list "$empty_data" "TestApp" 2>/dev/null) || true
[[ -z "$result" ]]
EOF

    [ "$status" -eq 0 ]
}

@test "decode_file_list rejects non-absolute paths" {
    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" bash --noprofile --norc << 'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/common.sh"
source "$PROJECT_ROOT/lib/uninstall/batch.sh"

bad_data=$(printf 'relative/path' | base64)
if result=$(decode_file_list "$bad_data" "TestApp" 2>/dev/null); then
    [[ -z "$result" ]]
else
    true
fi
EOF

    [ "$status" -eq 0 ]
}

@test "decode_file_list handles both BSD and GNU base64 formats" {
    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" bash --noprofile --norc << 'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/common.sh"
source "$PROJECT_ROOT/lib/uninstall/batch.sh"

test_paths="/path/to/file1
/path/to/file2"

encoded_data=$(printf '%s' "$test_paths" | base64 | tr -d '\n')

result=$(decode_file_list "$encoded_data" "TestApp")

[[ "$result" == *"/path/to/file1"* ]] || exit 1
[[ "$result" == *"/path/to/file2"* ]] || exit 1

[[ -n "$result" ]] || exit 1
EOF

    [ "$status" -eq 0 ]
}

@test "remove_mole deletes manual binaries and caches" {
    mkdir -p "$HOME/.local/bin"
    touch "$HOME/.local/bin/mole"
    touch "$HOME/.local/bin/mo"
    mkdir -p "$HOME/.config/mole" "$HOME/.cache/mole"

    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" PATH="/usr/bin:/bin" bash --noprofile --norc << 'EOF'
set -euo pipefail
start_inline_spinner() { :; }
stop_inline_spinner() { :; }
rm() {
    local -a flags=()
    local -a paths=()
    local arg
    for arg in "$@"; do
        if [[ "$arg" == -* ]]; then
            flags+=("$arg")
        else
            paths+=("$arg")
        fi
    done
    local path
    for path in "${paths[@]}"; do
        if [[ "$path" == "$HOME" || "$path" == "$HOME/"* ]]; then
            /bin/rm "${flags[@]}" "$path"
        fi
    done
    return 0
}
sudo() {
    if [[ "$1" == "rm" ]]; then
        shift
        rm "$@"
        return 0
    fi
    return 0
}
export -f start_inline_spinner stop_inline_spinner rm sudo
printf '\n' | "$PROJECT_ROOT/mole" remove
EOF

    [ "$status" -eq 0 ]
    [ ! -f "$HOME/.local/bin/mole" ]
    [ ! -f "$HOME/.local/bin/mo" ]
    [ ! -d "$HOME/.config/mole" ]
    [ ! -d "$HOME/.cache/mole" ]
}
