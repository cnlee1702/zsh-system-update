#!/bin/zsh

# zsh-system-update plugin
# System Update Script for Linux with Conda/Pip environments
# Compatible with zsh/oh-my-zsh plugin system

# Add plugin directory to fpath for completion discovery
fpath+="${0:A:h}"

zsu_import() {
    local module="$1"
    local plugin_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-system-update"
    local module_path="${plugin_dir}/${module}"

    if [[ -f "$module_path" ]]; then
        source "$module_path"
        return 0
    else
        print "ERROR: Cannot load module: $module" >&2
        return 1
    fi
}

# Import required modules
zsu_import "lib/utils/output.zsh"
zsu_import "lib/utils/cache.zsh"
zsu_import "lib/managers/apt-manager.zsh"
zsu_import "lib/managers/conda-manager.zsh"
zsu_import "lib/managers/pip-manager.zsh"
zsu_import "lib/managers/flatpak-manager.zsh"

# Main system update function
zsh-system-update() {
    # Hook guard to prevent undesired execution
    if [[ -n "${ZSU_RUNNING:-}" ]]; then
        return 0
    fi
    
    # Set execution guard
    local ZSU_RUNNING=1
    export ZSU_RUNNING
    
    # Ensure guard is cleared on exit
    trap 'unset ZSU_RUNNING' EXIT INT TERM
    
    # Local variables to avoid global namespace pollution
    local QUIET=false
    local SKIP_APT=false
    local SKIP_CONDA=false
    local SKIP_PIP=false
    local SKIP_FLATPAK=false
    local VERBOSE=false
    local DRY_RUN=false
    local FORCE_APT_UPDATE=false
    local FORCE_CONDA_UPDATE=false
    local FORCE_FLATPAK_UPDATE=false

    # Check for required commands
    check_dependencies() {
        local missing_commands=()
        local required_commands=("basename" "wc" "grep" "python")
        
        # Only require apt if not skipping APT updates
        if [[ "$SKIP_APT" != true ]]; then
            required_commands+=("apt")
        fi
        
        for cmd in "${required_commands[@]}"; do
            if ! command -v "$cmd" >/dev/null 2>&1; then
                missing_commands+=("$cmd")
            fi
        done
        
        if [[ ${#missing_commands[@]} -gt 0 ]]; then
            zsu_print_error "Missing required commands: ${missing_commands[*]}"
            zsu_print_error "Please ensure your PATH includes standard system directories"
            zsu_print_error "Current PATH: $PATH"
            return 1
        fi
    }

    # Function to run command with optional dry-run
    run_cmd() {
        local cmd="$1"
        local description="$2"
        
        if [[ "$VERBOSE" == true ]]; then
            zsu_print_status "Running: $cmd"
        elif [[ -n "$description" ]]; then
            zsu_print_status "$description"
        fi
        
        if [[ "$DRY_RUN" == true ]]; then
            echo "DRY RUN: $cmd"
            return 0
        fi
        
        # Suppress apt CLI warnings for non-verbose mode
        if [[ "$QUIET" == true ]]; then
            eval "$cmd" >/dev/null 2>&1
        elif [[ "$VERBOSE" == false && "$cmd" =~ "apt " ]]; then
            # For apt commands in non-verbose mode, suppress stderr warnings but keep stdout
            eval "$cmd" 2>/dev/null
        else
            eval "$cmd"
        fi
    }

    # Help function
    show_help() {
        cat << EOF
zsh-system-update - System Update Plugin

USAGE:
    zsh-system-update [OPTIONS]

OPTIONS:
    -h, --help          Show this help message
    -q, --quiet         Suppress most output
    -v, --verbose       Show detailed output including commands
    --dry-run           Show what would be executed without running
    --skip-apt          Skip APT system updates
    --skip-conda        Skip Conda updates
    --skip-pip          Skip pip updates
    --skip-flatpak      Skip Flatpak updates
    --apt-only          Only run APT updates
    --conda-only        Only run Conda/pip updates
    --flatpak-only      Only run Flatpak updates
    --force-apt-update  Force apt update even if recently updated
    --force-conda-update Force conda update even if recently updated
    --force-flatpak-update Force flatpak update even if recently updated

EXAMPLES:
    zsh-system-update                    # Full system update
    zsh-system-update --quiet            # Silent update
    zsh-system-update --apt-only         # Only system packages
    zsh-system-update --skip-apt         # Only Python environments
    zsh-system-update --dry-run          # Preview what would run

EOF
    }

    # Parse command line arguments
    parse_args() {
        while [[ $# -gt 0 ]]; do
            case $1 in
                -h|--help)
                    show_help
                    return 2  # Special return code to indicate help was shown
                    ;;
                -q|--quiet)
                    QUIET=true
                    shift
                    ;;
                -v|--verbose)
                    VERBOSE=true
                    shift
                    ;;
                --dry-run)
                    DRY_RUN=true
                    shift
                    ;;
                --skip-apt)
                    SKIP_APT=true
                    shift
                    ;;
                --skip-conda)
                    SKIP_CONDA=true
                    shift
                    ;;
                --skip-pip)
                    SKIP_PIP=true
                    shift
                    ;;
                --skip-flatpak)
                    SKIP_FLATPAK=true
                    shift
                    ;;
                --apt-only)
                    SKIP_CONDA=true
                    SKIP_PIP=true
                    SKIP_FLATPAK=true
                    shift
                    ;;
                --conda-only)
                    SKIP_APT=true
                    SKIP_FLATPAK=true
                    shift
                    ;;
                --flatpak-only)
                    SKIP_APT=true
                    SKIP_CONDA=true
                    SKIP_PIP=true
                    shift
                    ;;
                --force-apt-update)
                    FORCE_APT_UPDATE=true
                    shift
                    ;;
                --force-conda-update)
                    FORCE_CONDA_UPDATE=true
                    shift
                    ;;
                --force-flatpak-update)
                    FORCE_FLATPAK_UPDATE=true
                    shift
                    ;;
                *)
                    zsu_print_error "Unknown option: $1"
                    show_help
                    return 1
                    ;;
            esac
        done
        return 0
    }

    # Main execution logic
    main() {
        local start_time=$(date +%s)
        
        # Export current time for cache utilities
        export ZSU_CURRENT_TIME="$start_time"
        
        zsu_print_status "System update started at $(date)"
        
        if [[ "$DRY_RUN" == true ]]; then
            zsu_print_warning "DRY RUN MODE - No commands will be executed"
        fi
        
        # Detect conda installation early
        zsu_detect_conda_installation
        
        # Check for required dependencies
        if ! check_dependencies; then
            return 1
        fi
        
        # Run updates and update cache timestamps on success
        if zsu_update_apt $VERBOSE $SKIP_APT $QUIET $FORCE_APT_UPDATE; then
            zsu_cache_touch "apt"
        fi
        
        if zsu_update_flatpak $VERBOSE $SKIP_FLATPAK $QUIET $FORCE_FLATPAK_UPDATE $DRY_RUN; then
            zsu_cache_touch "flatpak"
        fi
        
        if zsu_update_conda $VERBOSE $SKIP_CONDA $QUIET $FORCE_CONDA_UPDATE; then
            zsu_cache_touch "conda"
        fi
        
        zsu_update_pip $VERBOSE $SKIP_PIP $QUIET $DRY_RUN
        
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        zsu_print_success "System update completed in ${duration} seconds"

        return 0
    }

    # Parse arguments first
    parse_args "$@"
    local parse_result=$?
    
    # If help was shown, exit
    if [[ $parse_result -eq 2 ]]; then
        return 0
    fi
    
    # If there was an error parsing, exit
    if [[ $parse_result -ne 0 ]]; then
        return 1
    fi
    
    # Run the main update function
    main

    return 0
}

# Tab completion for the function
_zsh_system_update() {
    local context state line
    
    _arguments \
        '(-h --help)'{-h,--help}'[Show help message]' \
        '(-q --quiet)'{-q,--quiet}'[Suppress most output]' \
        '(-v --verbose)'{-v,--verbose}'[Show detailed output]' \
        '--dry-run[Show what would be executed without running]' \
        '--skip-apt[Skip APT system updates]' \
        '--skip-conda[Skip Conda updates]' \
        '--skip-pip[Skip pip updates]' \
        '--skip-flatpak[Skip Flatpak updates]' \
        '--apt-only[Only run APT updates]' \
        '--conda-only[Only run Conda/pip updates]' \
        '--flatpak-only[Only run Flatpak updates]' \
        '--force-apt-update[Force apt update even if recently updated]' \
        '--force-conda-update[Force conda update even if recently updated]' \
        '--force-flatpak-update[Force flatpak update even if recently updated]'
}

# Register the completion function
compdef _zsh_system_update zsh-system-update