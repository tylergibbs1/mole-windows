#!/usr/bin/env bats

setup_file() {
    PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    export PROJECT_ROOT

    ORIGINAL_HOME="${HOME:-}"
    export ORIGINAL_HOME

    HOME="$(mktemp -d "${BATS_TEST_DIRNAME}/tmp-scripts-home.XXXXXX")"
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
    export TERM="dumb"
    rm -rf "${HOME:?}"/*
    mkdir -p "$HOME"
}

@test "format.sh --check validates script formatting" {
    if ! command -v shfmt > /dev/null 2>&1; then
        skip "shfmt not installed"
    fi

    run "$PROJECT_ROOT/scripts/format.sh" --check
    # May pass or fail depending on formatting, but should not error
    [[ "$status" -eq 0 || "$status" -eq 1 ]]
}

@test "format.sh --help shows usage information" {
    run "$PROJECT_ROOT/scripts/format.sh" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage"* ]]
}

@test "check.sh script exists and is valid" {
    # Don't actually run check.sh in tests - it would recursively run all bats tests!
    # Just verify the script is valid bash
    [ -f "$PROJECT_ROOT/scripts/check.sh" ]
    [ -x "$PROJECT_ROOT/scripts/check.sh" ]

    # Verify it has the expected structure
    run bash -c "grep -q 'Quality Checks' '$PROJECT_ROOT/scripts/check.sh'"
    [ "$status" -eq 0 ]
}

@test "build-analyze.sh detects missing Go toolchain" {
    if command -v go > /dev/null 2>&1; then
        skip "Go is installed, cannot test missing toolchain"
    fi

    run "$PROJECT_ROOT/scripts/build-analyze.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Go not installed"* ]]
}

@test "build-analyze.sh has version info support" {
    # Don't actually build in tests - too slow (10-30 seconds)
    # Just verify the script contains version info logic
    run bash -c "grep -q 'VERSION=' '$PROJECT_ROOT/scripts/build-analyze.sh'"
    [ "$status" -eq 0 ]
    run bash -c "grep -q 'BUILD_TIME=' '$PROJECT_ROOT/scripts/build-analyze.sh'"
    [ "$status" -eq 0 ]
}

@test "setup-quick-launchers.sh has detect_mo function" {
    # Don't actually run the script - it opens Raycast and creates files
    # Just verify it contains the detection logic
    run bash -c "grep -q 'detect_mo()' '$PROJECT_ROOT/scripts/setup-quick-launchers.sh'"
    [ "$status" -eq 0 ]
}

@test "setup-quick-launchers.sh has Raycast script generation" {
    # Don't actually run the script - it opens Raycast
    # Just verify it contains Raycast workflow creation logic
    run bash -c "grep -q 'create_raycast_commands' '$PROJECT_ROOT/scripts/setup-quick-launchers.sh'"
    [ "$status" -eq 0 ]
    run bash -c "grep -q 'write_raycast_script' '$PROJECT_ROOT/scripts/setup-quick-launchers.sh'"
    [ "$status" -eq 0 ]
}
