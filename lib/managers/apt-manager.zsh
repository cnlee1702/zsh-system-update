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

# Load cache utilities
if ! typeset -f zsu_cache_needs_update >/dev/null 2>&1; then
    local cache_module="lib/utils/cache.zsh"
    local plugin_dir="${TEST_PLUGIN_DIR:-${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-system-update}"
    local cache_module_path="${plugin_dir}/${cache_module}"
    source "${cache_module_path}"
fi

zsu_apt_update_needed() {
    local VERBOSE="${1:-false}"

    if zsu_cache_needs_update "apt"; then
        if [[ "$VERBOSE" == true ]]; then
            local time_since=$(zsu_cache_time_since_update_human "apt")
            zsu_print_status "Last apt update was ${time_since}, updating..."
        fi
        return 0  # Update needed
    else
        if [[ "$VERBOSE" == true ]]; then
            local time_since=$(zsu_cache_time_since_update_human "apt")
            zsu_print_status "Apt was updated recently (${time_since}), skipping update"
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