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
# zsu_import "lib/utils/cache.zsh"
zsu_import "lib/managers/apt-manager.zsh"
# zsu_import "lib/managers/conda-manager.zsh"
# zsu_import "lib/managers/pip-manager.zsh"
# zsu_import "lib/managers/flatpak-manager.zsh"

# Main system update function
zsh-system-update() {
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
    
    # Conda detection variables
    local CONDA_CMD=""
    local CONDA_BASE=""
    local CONDA_ENVS_DIR=""

    # Dynamic conda detection function
    local detect_conda_installation() {
        local conda_cmd=""
        local conda_base=""
        local envs_dir=""
        
        # Method 1: Check if conda is already in PATH
        if command -v conda >/dev/null 2>&1; then
            local conda_type=$(type -t conda 2>/dev/null || echo "unknown")
            
            if [[ "$conda_type" == "file" ]]; then
                # It's a real executable
                conda_cmd=$(command -v conda)
                if [[ "$VERBOSE" == true ]]; then
                    zsu_print_status "Found conda executable: $conda_cmd"
                fi
            elif [[ "$conda_type" == "function" || "$conda_type" == "alias" ]]; then
                # Conda is a function/alias, try to find the real conda binary
                if [[ "$VERBOSE" == true ]]; then
                    zsu_print_status "Conda is a $conda_type, searching for actual binary..."
                fi
                
                # Try to find conda binary in common locations within PATH
                local path_entries=(${(s.:.)PATH})
                for path_dir in "${path_entries[@]}"; do
                    if [[ -x "$path_dir/conda" ]]; then
                        conda_cmd="$path_dir/conda"
                        if [[ "$VERBOSE" == true ]]; then
                            zsu_print_status "Found conda binary in PATH: $conda_cmd"
                        fi
                        break
                    fi
                done
            fi
            
            # Try to derive base directory from conda command path
            if [[ -n "$conda_cmd" && "$conda_cmd" != "conda" ]]; then
                local conda_bin_dir=$(dirname "$conda_cmd")
                local potential_base=$(dirname "$conda_bin_dir")
                if [[ -d "$potential_base/conda-meta" ]]; then
                    conda_base="$potential_base"
                    if [[ "$VERBOSE" == true ]]; then
                        zsu_print_status "Derived conda base from PATH executable: $conda_base"
                    fi
                fi
            fi
        fi
        
        # Method 2: Check common installation locations
        if [[ -z "$conda_cmd" ]]; then
            local common_locations=(
                "$HOME/miniconda3"
                "$HOME/anaconda3"
                "$HOME/mambaforge"
                "$HOME/miniforge3"
                "/opt/miniconda3"
                "/opt/anaconda3"
                "/usr/local/miniconda3"
                "/usr/local/anaconda3"
            )
            
            for location in "${common_locations[@]}"; do
                if [[ -x "$location/bin/conda" ]]; then
                    conda_cmd="$location/bin/conda"
                    conda_base="$location"
                    if [[ "$VERBOSE" == true ]]; then
                        zsu_print_status "Found conda installation: $location"
                    fi
                    break
                fi
            done
        fi
        
        # Method 3: Check CONDA_PREFIX if set
        if [[ -z "$conda_cmd" && -n "$CONDA_PREFIX" && -x "$CONDA_PREFIX/bin/conda" ]]; then
            conda_cmd="$CONDA_PREFIX/bin/conda"
            conda_base="$CONDA_PREFIX"
            if [[ "$VERBOSE" == true ]]; then
                zsu_print_status "Found conda via CONDA_PREFIX: $CONDA_PREFIX"
            fi
        fi
        
        # Method 4: Check CONDA_EXE environment variable
        if [[ -z "$conda_cmd" && -n "$CONDA_EXE" && -x "$CONDA_EXE" ]]; then
            conda_cmd="$CONDA_EXE"
            if [[ "$VERBOSE" == true ]]; then
                zsu_print_status "Found conda via CONDA_EXE: $CONDA_EXE"
            fi
            
            # Try to derive base from CONDA_EXE
            local conda_bin_dir=$(dirname "$CONDA_EXE")
            local potential_base=$(dirname "$conda_bin_dir")
            if [[ -d "$potential_base/conda-meta" ]]; then
                conda_base="$potential_base"
                if [[ "$VERBOSE" == true ]]; then
                    zsu_print_status "Derived conda base from CONDA_EXE: $conda_base"
                fi
            fi
        fi
        
        # Determine environments directory
        if [[ -n "$conda_base" && -d "$conda_base/envs" ]]; then
            envs_dir="$conda_base/envs"
        fi
        
        # Set global variables for use in other functions
        CONDA_CMD="$conda_cmd"
        CONDA_BASE="$conda_base"
        CONDA_ENVS_DIR="$envs_dir"
        
        if [[ -n "$conda_cmd" ]]; then
            if [[ "$VERBOSE" == true ]]; then
                zsu_print_status "Conda detection successful:"
                zsu_print_status "  Command: $CONDA_CMD"
                zsu_print_status "  Base: $CONDA_BASE"
                zsu_print_status "  Envs: $CONDA_ENVS_DIR"
                
                # Show version if we have a real executable
                if [[ "$CONDA_CMD" != "conda" ]]; then
                    local conda_version=$($CONDA_CMD --version 2>/dev/null || echo "unknown")
                    zsu_print_status "  Version: $conda_version"
                fi
            fi
            return 0
        else
            if [[ "$VERBOSE" == true ]]; then
                zsu_print_warning "No conda installation detected - skipping conda operations"
            fi
            return 1
        fi
    }

    # Check for required commands
    local check_dependencies() {
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
    local run_cmd() {
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
    local show_help() {
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
    local parse_args() {
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

    # Check if conda update is needed (within last 2 hours)
    local conda_update_needed() {
        local update_threshold=7200  # 2 hours in seconds
        local current_time=$(date +%s)
        
        # Use detected conda base directory
        if [[ -z "$CONDA_BASE" ]]; then
            return 0  # No conda installation found, skip but don't error
        fi
        
        # Check conda's package cache directory
        local conda_pkgs_dir="$CONDA_BASE/pkgs"
        
        if [[ ! -d "$conda_pkgs_dir" ]]; then
            return 0  # No package directory found, assume update needed
        fi
        
        # Check conda's repodata cache
        local conda_cache_dir="$conda_pkgs_dir/cache"
        
        # Check conda info cache files
        local conda_info_cache="$HOME/.conda/environments.txt"
        local latest_timestamp=0
        
        # Check multiple possible cache locations
        local cache_files=(
            "$conda_cache_dir"
            "$HOME/.conda"
            "$conda_pkgs_dir/.conda_lock"
            "$conda_info_cache"
        )
        
        for cache_location in "${cache_files[@]}"; do
            if [[ -e "$cache_location" ]]; then
                local file_timestamp=$(stat -c %Y "$cache_location" 2>/dev/null || echo 0)
                if [[ $file_timestamp -gt $latest_timestamp ]]; then
                    latest_timestamp=$file_timestamp
                fi
            fi
        done
        
        # If we couldn't find any cache files, check when conda was last run
        if [[ $latest_timestamp -eq 0 ]]; then
            # Check conda history
            local conda_history="$CONDA_BASE/conda-meta/history"
            
            if [[ -f "$conda_history" ]]; then
                latest_timestamp=$(stat -c %Y "$conda_history" 2>/dev/null || echo 0)
            fi
        fi
        
        # If still no timestamp, assume update is needed
        if [[ $latest_timestamp -eq 0 ]]; then
            return 0
        fi
        
        local time_diff=$((current_time - latest_timestamp))
        
        if [[ $time_diff -gt $update_threshold ]]; then
            if [[ "$VERBOSE" == true ]]; then
                zsu_print_status "Last conda activity was $((time_diff / 60)) minutes ago, updating..."
            fi
            return 0  # Update needed
        else
            if [[ "$VERBOSE" == true ]]; then
                zsu_print_status "Conda data is recent ($((time_diff / 60)) minutes old), checking if conda itself needs update"
            fi
            return 1  # Update not needed
        fi
    }

    # Check if apt update is needed (within last hour)
    local apt_update_needed() {
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

    # APT update functions
    local update_apt() {
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
        if [[ "$FORCE_APT_UPDATE" == true ]] || apt_update_needed; then
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
    }

    # Conda update function
    local update_conda() {
        if [[ "$SKIP_CONDA" == true ]]; then
            zsu_print_status "Skipping Conda updates"
            return 0
        fi
        
        # Use dynamic conda detection
        if [[ -z "$CONDA_CMD" ]]; then
            zsu_print_warning "Conda not found, skipping conda updates"
            return 0
        fi
        
        zsu_print_status "Starting Conda updates..."
        
        # Debug: Show conda info
        if [[ "$VERBOSE" == true ]]; then
            zsu_print_status "Using conda at: $CONDA_CMD"
            zsu_print_status "Conda version: $($CONDA_CMD --version 2>/dev/null || echo 'unknown')"
        fi
        
        # Only update conda if needed (unless forced)
        if [[ "$FORCE_CONDA_UPDATE" == true ]] || conda_update_needed; then
            # Check if mamba is available in the same environment
            local mamba_available=false
            local conda_dir=$(dirname "$CONDA_CMD")
            if [[ -x "$conda_dir/mamba" ]]; then
                mamba_available=true
            fi
            
            if [[ "$mamba_available" == true ]]; then
                run_cmd "$CONDA_CMD update conda mamba --yes" "Updating conda and mamba"
            else
                run_cmd "$CONDA_CMD update conda --yes" "Updating conda"
            fi
            
            run_cmd "$CONDA_CMD clean --all --yes" "Cleaning conda cache"
        else
            zsu_print_status "Conda is recently updated, skipping conda update"
        fi
        
        zsu_print_success "Conda updates completed"
    }

    # Pip update function
    local update_pip() {
        if [[ "$SKIP_PIP" == true ]]; then
            zsu_print_status "Skipping pip updates"
            return 0
        fi
        
        zsu_print_status "Starting pip updates..."
        
        # Update pip in base environment
        run_cmd "python -m pip install --upgrade pip" "Upgrading pip in base environment"
        
        # Find and update pip in conda environments
        local env_count=0
        
        if [[ -n "$CONDA_ENVS_DIR" && -d "$CONDA_ENVS_DIR" ]]; then
            for env_path in "$CONDA_ENVS_DIR"/*; do
                if [[ -d "$env_path" && -f "$env_path/bin/pip" ]]; then
                    local env_name=$(basename "$env_path")
                    ((env_count++))
                    
                    if [[ "$VERBOSE" == true ]]; then
                        zsu_print_status "Updating pip in environment: $env_name"
                    fi
                    
                    # Use the detected conda command
                    run_cmd "$CONDA_CMD run -n $env_name python -m pip install --upgrade pip" "Upgrading pip in $env_name"
                fi
            done
            
            zsu_print_status "Updated pip in $env_count conda environments"
        else
            zsu_print_warning "No conda environments directory found"
        fi
        
        # Clean pip cache once at the end
        run_cmd "python -m pip cache purge" "Cleaning pip cache"
        
        zsu_print_success "Pip updates completed"
    }

    # Flatpak update function
    local update_flatpak() {
        if [[ "$SKIP_FLATPAK" == true ]]; then
            zsu_print_status "Skipping Flatpak updates"
            return 0
        fi
        
        # Check if flatpak is installed
        if ! command -v flatpak >/dev/null 2>&1; then
            zsu_print_warning "Flatpak not found, skipping Flatpak updates"
            return 0
        fi
        
        # Check cache unless forced (similar to conda cache check)
        local cache_threshold=7200  # 2 hours in seconds
        local current_time=$(date +%s)
        local cache_file="$HOME/.cache/flatpak"
        
        if [[ "$FORCE_FLATPAK_UPDATE" != true ]]; then
            if [[ -d "$cache_file" ]]; then
                local latest_timestamp=$(stat -c %Y "$cache_file" 2>/dev/null || echo 0)
                local time_diff=$((current_time - latest_timestamp))
                
                if [[ $time_diff -lt $cache_threshold ]]; then
                    if [[ "$VERBOSE" == true ]]; then
                        zsu_print_status "Flatpak updated recently ($((time_diff / 60)) minutes ago), skipping"
                    else
                        zsu_print_status "Flatpak applications are recent, skipping update"
                    fi
                    return 0
                fi
            fi
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
        
        # Update cache timestamp (only if not dry-run)
        if [[ "$DRY_RUN" != true ]]; then
            mkdir -p "$(dirname "$cache_file")" 2>/dev/null
            touch "$cache_file" 2>/dev/null
        fi
        
        zsu_print_success "Flatpak updates completed"
    }

    # Main execution logic
    local main() {
        local start_time=$(date +%s)
        
        zsu_print_status "System update started at $(date)"
        
        if [[ "$DRY_RUN" == true ]]; then
            zsu_print_warning "DRY RUN MODE - No commands will be executed"
        fi
        
        # Detect conda installation early
        detect_conda_installation
        
        # Check for required dependencies
        if ! check_dependencies; then
            return 1
        fi
        
        # Run updates
        zsu_update_apt $VERBOSE $SKIP_APT $QUIET $FORCE_APT_UPDATE
        update_conda  
        update_pip
        update_flatpak
        
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