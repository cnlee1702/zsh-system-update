#!/bin/zsh
# APT manager for zsh-system-update

# Dependency guard for output utilities
if ! typeset -f zsu_print_status >/dev/null 2>&1; then
    local module="lib/utils/output.zsh"
    local plugin_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-system-update"
    local module_path="${plugin_dir}/${module}"
    print "ERROR: zsu_print_status not found. Ensure output utilities are loaded." >&2
    source "${module_path}"
fi

zsu_apt_update_needed() {
    local VERBOSE="${1:-false}"

    local apt_lists_dir="/var/lib/apt/lists"
    local update_threshold=3600  # 1 hour in seconds
    local current_time=$(date +%s)
    
    # Check if apt lists directory exists and has recent files
    if [[ ! -d "$apt_lists_dir" ]]; then
        return 0  # Directory doesn't exist, update needed
    fi
    
    # Find the most recent file in apt lists directory
    local latest_file=$(find "$apt_lists_dir" -name "*Release*" -type f -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f1)
    
    if [[ -z "$latest_file" ]]; then
        return 0  # No Release files found, update needed
    fi
    
    # Convert to integer (remove decimal part)
    latest_file=${latest_file%.*}
    local time_diff=$((current_time - latest_file))
    
    if [[ $time_diff -gt $update_threshold ]]; then
        if [[ "$VERBOSE" == true ]]; then
            zsu_print_status "Last apt update was $((time_diff / 60)) minutes ago, updating..."
        fi
        return 0  # Update needed
    else
        if [[ "$VERBOSE" == true ]]; then
            zsu_print_status "Apt lists are recent ($((time_diff / 60)) minutes old), skipping update"
        fi
        return 1  # Update not needed
    fi

}

zsu_update_apt() {
    local VERBOSE="${1:-false}"
    local SKIP_APT="${2:-false}"
    local QUIET="${3:-false}"
    local FORCE_APT_UPDATE="${4:-false}"

    if [[ "$SKIP_APT" == true ]]; then
        zsu_print_status "Skipping APT updates"
        return 0
    fi
    
    # Check if apt is available (for non-Debian systems)
    if ! command -v apt-get >/dev/null 2>&1; then
        zsu_print_warning "APT not found, skipping APT updates"
        return 0
    fi
    
    zsu_print_status "Starting APT updates..."
    
    local apt_quiet=""
    local apt_config=""
    
    if [[ "$QUIET" == true ]]; then
        apt_quiet="-qq"
    fi
    
    # Auto-handle configuration prompts
    apt_config='-o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"'
    
    # Only update package lists if needed (unless forced)
    if [[ "$FORCE_APT_UPDATE" == true ]] || zsu_apt_update_needed $VERBOSE; then
        run_cmd "sudo apt-get update $apt_quiet" "Updating package lists"
    else
        zsu_print_status "Package lists are recent, skipping update"
    fi
    
    # Check if upgrades are available using apt-get (more script-friendly)
    if apt list --upgradable 2>/dev/null | grep -q "upgradable" 2>/dev/null; then
        run_cmd "sudo apt-get upgrade --yes --no-install-recommends $apt_config" "Upgrading packages"
    else
        zsu_print_status "No packages to upgrade"
    fi
    
    run_cmd "sudo apt-get autoremove --yes --purge" "Removing unnecessary packages"
    run_cmd "sudo apt-get autoclean" "Cleaning package cache"
    
    zsu_print_success "APT updates completed"

    return 0

}