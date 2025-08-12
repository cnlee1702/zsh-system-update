#!/bin/zsh
# Flatpak manager for zsh-system-update

# Dependency guard for output utilities
# Load output utilities in isolated scope
_zsu_load_output_utils() {
    if ! typeset -f zsu_print_status >/dev/null 2>&1; then
        local module="lib/utils/output.zsh"
        local plugin_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-system-update"
        local module_path="${plugin_dir}/${module}"
        print "ERROR: zsu_print_status not found. Ensure output utilities are loaded." >&2
        source "${module_path}"
    fi
    unset -f _zsu_load_output_utils
}
_zsu_load_output_utils

# Load cache utilities in isolated scope
_zsu_load_cache_utils() {
    if ! typeset -f zsu_cache_needs_update >/dev/null 2>&1; then
        local cache_module="lib/utils/cache.zsh"
        local plugin_dir="${TEST_PLUGIN_DIR:-${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-system-update}"
        local cache_module_path="${plugin_dir}/${cache_module}"
        source "${cache_module_path}"
    fi
    unset -f _zsu_load_cache_utils
}
_zsu_load_cache_utils

 # Flatpak update function

zsu_update_flatpak() {
    VERBOSE="${1:-false}"
    SKIP_FLATPAK=${2:-false}
    QUIET="${3:-false}"
    FORCE_FLATPAK_UPDATE="${4:-false}"
    DRY_RUN="${5:-false}"

    if [[ "$SKIP_FLATPAK" == true ]]; then
        zsu_print_status "Skipping Flatpak updates"
        return 0
    fi
    
    # Check if flatpak is installed
    if ! command -v flatpak >/dev/null 2>&1; then
        zsu_print_warning "Flatpak not found, skipping Flatpak updates"
        return 0
    fi
    
    # Check cache unless forced
    if [[ "$FORCE_FLATPAK_UPDATE" != true ]] && ! zsu_cache_needs_update "flatpak"; then
        if [[ "$VERBOSE" == true ]]; then
            local time_since=$(zsu_cache_time_since_update_human "flatpak")
            zsu_print_status "Flatpak updated recently (${time_since}), skipping"
        else
            zsu_print_status "Flatpak applications are recent, skipping update"
        fi
        return 0
    fi
    
    zsu_print_status "Starting Flatpak updates..."
    
    # Update repositories
    if [[ "$VERBOSE" == true ]]; then
        zsu_print_status "Updating Flatpak repositories"
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        echo "DRY RUN: flatpak update --appstream"
    else
        if [[ "$QUIET" == true ]]; then
            flatpak update --appstream >/dev/null 2>&1
        else
            flatpak update --appstream
        fi
    fi
    
    # Check for updates and update applications
    local updates_available=false
    if [[ "$DRY_RUN" != true ]]; then
        if flatpak remote-ls --updates 2>/dev/null | grep -q .; then
            updates_available=true
        fi
    else
        # In dry-run mode, assume updates might be available
        updates_available=true
    fi
    
    if [[ "$updates_available" == true ]]; then
        if [[ "$VERBOSE" == true ]]; then
            zsu_print_status "Updating Flatpak applications"
        fi
        
        if [[ "$DRY_RUN" == true ]]; then
            echo "DRY RUN: flatpak update --assumeyes"
        else
            if [[ "$QUIET" == true ]]; then
                flatpak update --assumeyes >/dev/null 2>&1
            else
                flatpak update --assumeyes
            fi
        fi
    else
        zsu_print_status "No Flatpak applications to update"
    fi
    
    # Clean up unused runtimes
    if [[ "$VERBOSE" == true ]]; then
        zsu_print_status "Cleaning unused Flatpak runtimes"
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        echo "DRY RUN: flatpak uninstall --unused --assumeyes"
    else
        if [[ "$QUIET" == true ]]; then
            flatpak uninstall --unused --assumeyes >/dev/null 2>&1
        else
            flatpak uninstall --unused --assumeyes
        fi
    fi
    
    
    zsu_print_success "Flatpak updates completed"

    return 0
}
