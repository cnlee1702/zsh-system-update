#!/bin/zsh

# zsh-system-update plugin
# System Update Script for Linux Mint with Conda/Pip environments
# Compatible with zsh/oh-my-zsh plugin system

# Add plugin directory to fpath for completion discovery
fpath+="${0:A:h}"

# Debug function to check what's happening
debug_zsh_system_update() {
    echo "Plugin loaded at: ${0:A:h}"
    echo "Functions defined:"
    typeset -f | grep "zsh-system-update"
    echo "Aliases:"
    alias | grep -i update
    echo "Conda function exists:"
    typeset -f conda | head -5
}

# Main system update function - single definition
zsh-system-update() {
    # Local variables to avoid global namespace pollution
    local QUIET=false
    local SKIP_APT=false
    local SKIP_CONDA=false
    local SKIP_PIP=false
    local VERBOSE=false
    local DRY_RUN=false
    local FORCE_APT_UPDATE=false
    local FORCE_CONDA_UPDATE=false

    # Colors for output - ensure they're loaded first
    if [[ -z "$fg" ]]; then
        autoload -U colors && colors
    fi
    
    # Helper functions with explicit color handling
    local print_status() {
        print -P "%F{blue}[INFO]%f $1"
    }

    # Function to update Flatpak applications
    local update_flatpak_packages() {
        # Check if flatpak is installed
        if ! command -v flatpak >/dev/null 2>&1; then
            print_status "WARNING" "Flatpak not found, skipping Flatpak updates"
            return 0
        fi
        
        # Check cache unless forced
        local cache_file="$HOME/.cache/zsh-system-update/flatpak_last_update"
        local cache_hours=2
        
        if [[ "$force_flatpak" != true ]] && check_cache "$cache_file" $cache_hours; then
            print_status "INFO" "Flatpak applications updated recently (within ${cache_hours}h), skipping"
            return 0
        fi
        
        print_status "INFO" "Starting Flatpak updates..."
        
        # Update repositories
        print_status "INFO" "Updating Flatpak repositories"
        execute_command "flatpak update --appstream"
        
        # Check for updates
        local updates_available
        if updates_available=$(flatpak remote-ls --updates 2>/dev/null) && [[ -n "$updates_available" ]]; then
            print_status "INFO" "Updating Flatpak applications"
            execute_command "flatpak update --assumeyes"
        else
            print_status "INFO" "No Flatpak applications to update"
        fi
        
        # Clean up unused runtimes
        print_status "INFO" "Cleaning unused Flatpak runtimes"
        execute_command "flatpak uninstall --unused --assumeyes"
        
        # Update cache timestamp
        update_cache "$cache_file"
        
        print_status "SUCCESS" "Flatpak updates completed"
    }

    local print_success() {
        print -P "%F{green}[SUCCESS]%f $1"
    }

    local print_warning() {
        print -P "%F{yellow}[WARNING]%f $1"
    }

    local print_error() {
        print -P "%F{red}[ERROR]%f $1"
    }

    # Check for required commands
    local check_dependencies() {
        local missing_commands=()
        local required_commands=("basename" "wc" "grep" "apt" "python")
        
        for cmd in "${required_commands[@]}"; do
            if ! command -v "$cmd" >/dev/null 2>&1; then
                missing_commands+=("$cmd")
            fi
        done
        
        if [[ ${#missing_commands[@]} -gt 0 ]]; then
            print_error "Missing required commands: ${missing_commands[*]}"
            print_error "Please ensure your PATH includes standard system directories"
            print_error "Current PATH: $PATH"
            return 1
        fi
    }

    # Function to run command with optional dry-run
    local run_cmd() {
        local cmd="$1"
        local description="$2"
        
        if [[ "$VERBOSE" == true ]]; then
            print_status "Running: $cmd"
        elif [[ -n "$description" ]]; then
            print_status "$description"
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
    --apt-only          Only run APT updates
    --conda-only        Only run Conda/pip updates
    --force-apt-update  Force apt update even if recently updated
    --force-conda-update Force conda update even if recently updated

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
                --apt-only)
                    SKIP_CONDA=true
                    SKIP_PIP=true
                    shift
                    ;;
                --conda-only)
                    SKIP_APT=true
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
                *)
                    print_error "Unknown option: $1"
                    show_help
                    return 1
                    ;;
            esac
        done
        return 0
    }

    # Check if conda update is needed (within last 2 hours)
    local conda_update_needed() {
        local conda_cmd="/home/cli/miniconda3/bin/conda"
        local update_threshold=7200  # 2 hours in seconds (conda updates less frequently)
        local current_time=$(date +%s)
        
        # Check conda's package cache directory
        local conda_pkgs_dir="$HOME/miniconda3/pkgs"
        if [[ ! -d "$conda_pkgs_dir" ]]; then
            conda_pkgs_dir="$HOME/anaconda3/pkgs"
        fi
        
        if [[ ! -d "$conda_pkgs_dir" ]]; then
            return 0  # No conda installation found, skip but don't error
        fi
        
        # Check conda's repodata cache
        local conda_cache_dir="$HOME/miniconda3/pkgs/cache"
        if [[ ! -d "$conda_cache_dir" ]]; then
            conda_cache_dir="$HOME/anaconda3/pkgs/cache"
        fi
        
        # Alternative: check conda info cache files
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
            local conda_history="$HOME/miniconda3/conda-meta/history"
            if [[ ! -f "$conda_history" ]]; then
                conda_history="$HOME/anaconda3/conda-meta/history"
            fi
            
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
                print_status "Last conda activity was $((time_diff / 60)) minutes ago, updating..."
            fi
            return 0  # Update needed
        else
            if [[ "$VERBOSE" == true ]]; then
                print_status "Conda data is recent ($((time_diff / 60)) minutes old), checking if conda itself needs update"
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
                print_status "Last apt update was $((time_diff / 60)) minutes ago, updating..."
            fi
            return 0  # Update needed
        else
            if [[ "$VERBOSE" == true ]]; then
                print_status "Apt lists are recent ($((time_diff / 60)) minutes old), skipping update"
            fi
            return 1  # Update not needed
        fi
    }

    # APT update functions
    local update_apt() {
        if [[ "$SKIP_APT" == true ]]; then
            print_status "Skipping APT updates"
            return 0
        fi
        
        print_status "Starting APT updates..."
        
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
            print_status "Package lists are recent, skipping update"
        fi
        
        # Check if upgrades are available using apt-get (more script-friendly)
        if apt list --upgradable 2>/dev/null | grep -q "upgradable" 2>/dev/null; then
            run_cmd "sudo apt-get upgrade --yes --no-install-recommends $apt_config" "Upgrading packages"
        else
            print_status "No packages to upgrade"
        fi
        
        run_cmd "sudo apt-get autoremove --yes --purge" "Removing unnecessary packages"
        run_cmd "sudo apt-get autoclean" "Cleaning package cache"
        
        print_success "APT updates completed"
    }

    # Conda update function
    local update_conda() {
        if [[ "$SKIP_CONDA" == true ]]; then
            print_status "Skipping Conda updates"
            return 0
        fi
        
        # Check if conda is available
        if ! command -v conda >/dev/null 2>&1; then
            print_warning "Conda not found, skipping conda updates"
            return 0
        fi
        
        print_status "Starting Conda updates..."
        
        # Don't reinitialize conda - use absolute path to avoid recursion
        local conda_cmd="/home/cli/miniconda3/bin/conda"
        
        # Debug: Check conda info
        if [[ "$VERBOSE" == true ]]; then
            print_status "Using conda at: $conda_cmd"
            print_status "Conda version: $($conda_cmd --version 2>/dev/null || echo 'unknown')"
        fi
        
        # Use absolute path to conda to avoid any function/alias interference
        # Only update conda if needed (unless forced)
        if [[ "$FORCE_CONDA_UPDATE" == true ]] || conda_update_needed; then
            run_cmd "$conda_cmd update conda mamba --yes" "Updating conda and mamba"
            run_cmd "$conda_cmd clean --all --yes" "Cleaning conda cache"
        else
            print_status "Conda is recently updated, skipping conda update"
        fi
        
        print_success "Conda updates completed"
    }

    # Pip update function
    local update_pip() {
        if [[ "$SKIP_PIP" == true ]]; then
            print_status "Skipping pip updates"
            return 0
        fi
        
        print_status "Starting pip updates..."
        
        # Update pip in base environment
        run_cmd "python -m pip install --upgrade pip" "Upgrading pip in base environment"
        
        # Find and update pip in conda environments
        local env_count=0
        local envs_dir="$HOME/miniconda3/envs"
        
        # Check common conda installation paths
        if [[ ! -d "$envs_dir" ]]; then
            envs_dir="$HOME/anaconda3/envs"
        fi
        
        if [[ -d "$envs_dir" ]]; then
            for env_path in "$envs_dir"/*; do
                if [[ -d "$env_path" && -f "$env_path/bin/pip" ]]; then
                    local env_name=$(basename "$env_path")
                    ((env_count++))
                    
                    if [[ "$VERBOSE" == true ]]; then
                        print_status "Updating pip in environment: $env_name"
                    fi
                    
                    # Use absolute path for conda to avoid recursion
                    local conda_cmd="/home/cli/miniconda3/bin/conda"
                    run_cmd "$conda_cmd run -n $env_name python -m pip install --upgrade pip" "Upgrading pip in $env_name"
                    ((env_count++))
                fi
            done
            
            print_status "Updated pip in $env_count conda environments"
        else
            print_warning "No conda environments directory found"
        fi
        
        # Clean pip cache once at the end
        run_cmd "python -m pip cache purge" "Cleaning pip cache"
        
        print_success "Pip updates completed"
    }

    # Main execution logic
    local main() {
        local start_time=$(date +%s)
        
        # Check for required dependencies first
        if ! check_dependencies; then
            return 1
        fi
        
        print_status "System update started at $(date)"
        
        if [[ "$DRY_RUN" == true ]]; then
            print_warning "DRY RUN MODE - No commands will be executed"
        fi
        
        # Run updates
        update_apt
        update_flatpak_packages
        update_conda  
        update_pip
        
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        print_success "System update completed in ${duration} seconds"
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
        '--apt-only[Only run APT updates]' \
        '--conda-only[Only run Conda/pip updates]' \
        '--force-apt-update[Force apt update even if recently updated]' \
        '--force-conda-update[Force conda update even if recently updated]'
}

# Register the completion function
compdef _zsh_system_update zsh-system-update