#!/bin/bash
# Mole - Installers command
# Highlights and helps remove installer files (.dmg, .pkg, .mpkg, .iso, .xip, .zip)

set -euo pipefail

# shellcheck disable=SC2154
# External variables set by menu_paginated.sh and environment
declare MOLE_SELECTION_RESULT
declare MOLE_INSTALLER_SCAN_MAX_DEPTH

export LC_ALL=C
export LANG=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/core/common.sh"
source "$SCRIPT_DIR/../lib/ui/menu_paginated.sh"


cleanup() {
    show_cursor
    cleanup_temp_files
}
trap cleanup EXIT
trap 'trap - EXIT; cleanup; exit 130' INT TERM

# Scan configuration
readonly INSTALLER_SCAN_MAX_DEPTH_DEFAULT=2
readonly INSTALLER_SCAN_PATHS=(
  "$HOME/Downloads"
  "$HOME/Desktop"
  "$HOME/Documents"
  "$HOME/Public"
  "$HOME/Library/Downloads"
  "/Users/Shared"
  "/Users/Shared/Downloads"  # Search one level deeper
)
readonly MAX_ZIP_ENTRIES=5

# Check for installer payloads inside ZIP (single pass, fused size and pattern check)
is_installer_zip() {
    local zip="$1"
    local cap="$MAX_ZIP_ENTRIES"

    zipinfo -1 "$zip" >/dev/null 2>&1 || return 1

    zipinfo -1 "$zip" 2>/dev/null \
        | head -n $((cap + 1)) \
        | awk -v cap="$cap" '
            /\.(app|pkg|dmg|xip)(\/|$)/ { found=1 }
            END {
                if (NR > cap) exit 1
                exit found ? 0 : 1
            }
        '
}

scan_installers_in_path() {
    local path="$1"
    local max_depth="${MOLE_INSTALLER_SCAN_MAX_DEPTH:-$INSTALLER_SCAN_MAX_DEPTH_DEFAULT}"

    [[ -d "$path" ]] || return 0

    local file

    if command -v fd > /dev/null 2>&1; then
        while IFS= read -r file; do
            [[ -L "$file" ]] && continue  # Skip symlinks explicitly
            case "$file" in
                *.dmg|*.pkg|*.mpkg|*.iso|*.xip)
                    echo "$file"
                    ;;
                *.zip)
                    [[ -r "$file" ]] || continue
                    if is_installer_zip "$file" 2>/dev/null; then
                        echo "$file"
                    fi
                    ;;
            esac
        done < <(
            fd --no-ignore --hidden --type f --max-depth "$max_depth" \
                -e dmg -e pkg -e mpkg -e iso -e xip -e zip \
                . "$path" 2>/dev/null || true
        )
    else
        while IFS= read -r file; do
            [[ -L "$file" ]] && continue  # Skip symlinks explicitly
            case "$file" in
                *.dmg|*.pkg|*.mpkg|*.iso|*.xip)
                    echo "$file"
                    ;;
                *.zip)
                    [[ -r "$file" ]] || continue
                    if is_installer_zip "$file" 2>/dev/null; then
                        echo "$file"
                    fi
                    ;;
            esac
        done < <(
            find "$path" -maxdepth "$max_depth" -type f \
                \( -name '*.dmg' -o -name '*.pkg' -o -name '*.mpkg' \
                   -o -name '*.iso' -o -name '*.xip' -o -name '*.zip' \) \
                2>/dev/null || true
        )
    fi
}

scan_all_installers() {
    for path in "${INSTALLER_SCAN_PATHS[@]}"; do
        scan_installers_in_path "$path"
    done
}

# Initialize stats
declare -i total_deleted=0
declare -i total_size_freed_kb=0

# Global arrays for installer data
declare -a INSTALLER_PATHS=()
declare -a INSTALLER_SIZES=()
declare -a DISPLAY_NAMES=()

# Collect all installers with their metadata
collect_installers() {
    printf '\n'
    echo -e "${BLUE}━━━ Scanning for installers ━━━${NC}"

    # Clear previous results
    INSTALLER_PATHS=()
    INSTALLER_SIZES=()
    DISPLAY_NAMES=()

    # Scan all paths, deduplicate, and sort results
    local -a all_files=()
    local sorted_paths
    sorted_paths=$(scan_all_installers | sort -u)

    if [[ -z "$sorted_paths" ]]; then
        echo -e "  ${YELLOW}No installer files found${NC}"
        return 1
    fi

    # Read sorted results into array
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        all_files+=("$file")
    done <<< "$sorted_paths"

    # Process each installer
    for file in "${all_files[@]}"; do
        # Calculate file size
        local file_size=0
        if [[ -f "$file" ]]; then
            file_size=$(get_file_size "$file")
        fi

        # Store installer path and size in parallel arrays
        INSTALLER_PATHS+=("$file")
        INSTALLER_SIZES+=("$file_size")
        DISPLAY_NAMES+=("$(basename "$file")")
    done

    echo -e "  ${GREEN}Found ${#INSTALLER_PATHS[@]} installer(s)${NC}"
    return 0
}

# Show menu for user selection
show_installer_menu() {
    if [[ ${#DISPLAY_NAMES[@]} -eq 0 ]]; then
        return 1
    fi

    echo ""

    local title="Select installers to remove"
    MOLE_SELECTION_RESULT=""
    paginated_multi_select "$title" "${DISPLAY_NAMES[@]}"
    local selection_exit=$?

    if [[ $selection_exit -ne 0 ]]; then
        echo ""
        echo -e "${YELLOW}Cancelled${NC}"
        return 1
    fi

    return 0
}

# Delete selected installers
delete_selected_installers() {
    # Parse selection indices
    local -a selected_indices=()
    [[ -n "$MOLE_SELECTION_RESULT" ]] && IFS=',' read -ra selected_indices <<<"$MOLE_SELECTION_RESULT"

    if [[ ${#selected_indices[@]} -eq 0 ]]; then
        return 1
    fi

    printf '\n'
    echo -e "${BLUE}━━━ Removing installers ━━━${NC}"

    # Delete each selected installer
    total_deleted=0
    total_size_freed_kb=0
    for idx in "${selected_indices[@]}"; do
        if [[ ! "$idx" =~ ^[0-9]+$ ]] || [[ $idx -ge ${#INSTALLER_PATHS[@]} ]]; then
            continue
        fi

        local file_path="${INSTALLER_PATHS[$idx]}"
        local file_size="${INSTALLER_SIZES[$idx]}"

        # Validate path before deletion
        if ! validate_path_for_deletion "$file_path"; then
            echo -e "  ${RED}${ICON_FAILED}${NC} Cannot delete (invalid path): $(basename "$file_path")"
            continue
        fi

        # Delete the file
        if safe_remove "$file_path" true; then
            local human_size
            human_size=$(bytes_to_human "$file_size")
            total_size_freed_kb=$((total_size_freed_kb + ((file_size + 1023) / 1024)))
            echo -e "  ${GREEN}${ICON_SUCCESS}${NC} Deleted: $(basename "$file_path") ${GRAY}($human_size)${NC}"
            total_deleted=$((total_deleted + 1))
        else
            echo -e "  ${RED}${ICON_FAILED}${NC} Failed to delete: $(basename "$file_path")"
        fi
    done

    return 0
}

# Perform the installers cleanup
perform_installers() {
    # Collect installers
    if ! collect_installers; then
        return 2  # Nothing to clean
    fi

    # Show menu
    if ! show_installer_menu; then
        return 1  # User cancelled
    fi

    # Delete selected
    delete_selected_installers

    return 0
}

show_summary() {
    echo ""
    local summary_heading="Cleanup complete"
    local -a summary_details=()

    if [[ $total_deleted -gt 0 ]]; then
        local freed_mb
        freed_mb=$(echo "$total_size_freed_kb" | awk '{printf "%.2f", $1/1024}')

        summary_details+=("Installers removed: $total_deleted")
        summary_details+=("Space freed: ${GREEN}${freed_mb}MB${NC}")
        summary_details+=("Free space now: $(get_free_space)")
    else
        summary_details+=("No installers were removed")
        summary_details+=("Free space now: $(get_free_space)")
    fi

    print_summary_block "$summary_heading" "${summary_details[@]}"
    printf '\n'
}

show_help() {
    echo -e "${PURPLE_BOLD}Mole Installers${NC} - Find and remove installer files"
    echo ""
    echo -e "${YELLOW}Usage:${NC} mo installers [options]"
    echo ""
    echo -e "${YELLOW}Options:${NC}"
    echo "  --debug         Enable debug logging"
    echo "  --help          Show this help message"
    echo ""
    echo -e "${YELLOW}Default Paths${NC}"
    echo "  - ${HOME}/Downloads"
    echo "  - ${HOME}/Desktop"
    echo "  - ${HOME}/Documents"
    echo "  - ${HOME}/Public"
    echo "  - ${HOME}/Library/Downloads"
    echo "  - /Users/Shared"
}

main() {
    for arg in "$@"; do
        case "$arg" in
            "--help")
                show_help
                exit 0
                ;;
            "--debug")
                export MO_DEBUG=1
                ;;
            *)
                echo "Unknown option: $arg"
                echo "Use 'mo installers --help' for usage information"
                exit 1
                ;;
        esac
    done

    # Clear screen for better UX
    if [[ -t 1 ]]; then
        printf '\033[2J\033[H'
    fi
    printf '\n'
    echo -e "${PURPLE_BOLD}Find & Remove Installers${NC}"

    hide_cursor
    perform_installers
    local exit_code=$?
    show_cursor

    case $exit_code in
        0)
            show_summary
            ;;
        1)
            printf '\n'
            ;;
        2)
            printf '\n'
            echo -e "${YELLOW}No installer files found in default locations${NC}"
            printf '\n'
            ;;
    esac

    return 0
}

# Only run main if not in test mode
if [[ "${MOLE_TEST_MODE:-0}" != "1" ]]; then
    main "$@"
fi
