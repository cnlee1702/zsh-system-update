#!/bin/zsh
# Conda manager for zsh-system-update

# Dependency guard for output utilities
if ! typeset -f zsu_print_status >/dev/null 2>&1; then
    local module="lib/utils/output.zsh"
    local plugin_dir="${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins/zsh-system-update"
    local module_path="${plugin_dir}/${module}"
    print "ERROR: zsu_print_status not found. Ensure output utilities are loaded." >&2
    source "${module_path}"
fi

# Conda detection variables
local CONDA_CMD=""
local CONDA_BASE=""
local CONDA_ENVS_DIR=""

# Dynamic conda detection function
zsu_detect_conda_installation() {
    local conda_cmd=""
    local conda_base=""
    local envs_dir=""
    
    # Method 1: Check if conda is already in PATH
    if command -v conda >/dev/null 2>&1; then
        local conda_type=$(type -t conda 2>/dev/null || echo "unknown")
        
        if [[ "${conda_type}" == "file" ]]; then
            # It's a real executable
            conda_cmd=$(command -v conda)
            if [[ "${VERBOSE}" == true ]]; then
                zsu_print_status "Found conda executable: ${conda_cmd}"
            fi
        elif [[ "${conda_type}" == "function" || "${conda_type}" == "alias" ]]; then
            # Conda is a function/alias, try to find the real conda binary
            if [[ "${VERBOSE}" == true ]]; then
                zsu_print_status "Conda is a ${conda_type}, searching for actual binary..."
            fi
            
            # Try to find conda binary in common locations within PATH
            local path_entries=(${(s.:.)PATH})
            for path_dir in "${path_entries[@]}"; do
                if [[ -x "${path_dir}/conda" ]]; then
                    conda_cmd="${path_dir}/conda"
                    if [[ "${VERBOSE}" == true ]]; then
                        zsu_print_status "Found conda binary in PATH: ${conda_cmd}"
                    fi
                    break
                fi
            done
        fi
        
        # Try to derive base directory from conda command path
        if [[ -n "${conda_cmd}" && "${conda_cmd}" != "conda" ]]; then
            local conda_bin_dir=$(dirname "${conda_cmd}")
            local potential_base=$(dirname "${conda_bin_dir}")
            if [[ -d "${potential_base}/conda-meta" ]]; then
                conda_base="${potential_base}"
                if [[ "${VERBOSE}" == true ]]; then
                    zsu_print_status "Derived conda base from PATH executable: ${conda_base}"
                fi
            fi
        fi
    fi
    
    # Method 2: Check common installation locations
    if [[ -z "${conda_cmd}" ]]; then
        local common_locations=(
            "${HOME}/miniconda3"
            "${HOME}/anaconda3"
            "${HOME}/mambaforge"
            "${HOME}/miniforge3"
            "/opt/miniconda3"
            "/opt/anaconda3"
            "/usr/local/miniconda3"
            "/usr/local/anaconda3"
        )
        
        for location in "${common_locations[@]}"; do
            if [[ -x "${location}/bin/conda" ]]; then
                conda_cmd="${location}/bin/conda"
                conda_base="${location}"
                if [[ "${VERBOSE}" == true ]]; then
                    zsu_print_status "Found conda installation: ${location}"
                fi
                break
            fi
        done
    fi
    
    # Method 3: Check CONDA_PREFIX if set
    if [[ -z "${conda_cmd}" && -n "${CONDA_PREFIX}" && -x "${CONDA_PREFIX}/bin/conda" ]]; then
        conda_cmd="${CONDA_PREFIX}/bin/conda"
        conda_base="${CONDA_PREFIX}"
        if [[ "${VERBOSE}" == true ]]; then
            zsu_print_status "Found conda via CONDA_PREFIX: ${CONDA_PREFIX}"
        fi
    fi
    
    # Method 4: Check CONDA_EXE environment variable
    if [[ -z "${conda_cmd}" && -n "${CONDA_EXE}" && -x "${CONDA_EXE}" ]]; then
        conda_cmd="${CONDA_EXE}"
        if [[ "${VERBOSE}" == true ]]; then
            zsu_print_status "Found conda via CONDA_EXE: ${CONDA_EXE}"
        fi
        
        # Try to derive base from CONDA_EXE
        local conda_bin_dir=$(dirname "${CONDA_EXE}")
        local potential_base=$(dirname "${conda_bin_dir}")
        if [[ -d "${potential_base}/conda-meta" ]]; then
            conda_base="${potential_base}"
            if [[ "${VERBOSE}" == true ]]; then
                zsu_print_status "Derived conda base from CONDA_EXE: ${conda_base}"
            fi
        fi
    fi
    
    # Determine environments directory
    if [[ -n "${conda_base}" && -d "${conda_base}/envs" ]]; then
        envs_dir="${conda_base}/envs"
    fi
    
    # Set global variables for use in other functions
    CONDA_CMD="${conda_cmd}"
    CONDA_BASE="${conda_base}"
    CONDA_ENVS_DIR="${envs_dir}"
    
    if [[ -n "${conda_cmd}" ]]; then
        if [[ "${VERBOSE}" == true ]]; then
            zsu_print_status "Conda detection successful:"
            zsu_print_status "  Command: ${CONDA_CMD}"
            zsu_print_status "  Base: ${CONDA_BASE}"
            zsu_print_status "  Envs: ${CONDA_ENVS_DIR}"
            
            # Show version if we have a real executable
            if [[ "${CONDA_CMD}" != "conda" ]]; then
                local conda_version=$(${CONDA_CMD} --version 2>/dev/null || echo "unknown")
                zsu_print_status "  Version: ${conda_version}"
            fi
        fi
        return 0
    else
        if [[ "${VERBOSE}" == true ]]; then
            zsu_print_warning "No conda installation detected - skipping conda operations"
        fi
        return 1
    fi
}

# Check if conda update is needed (within last 2 hours)
zsu_conda_update_needed() {
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
    
    if [[ ${time_diff} -gt ${update_threshold} ]]; then
        if [[ "${VERBOSE}" == true ]]; then
            zsu_print_status "Last conda activity was $((time_diff / 60)) minutes ago, updating..."
        fi
        return 0  # Update needed
    else
        if [[ "${VERBOSE}" == true ]]; then
            zsu_print_status "Conda data is recent ($((time_diff / 60)) minutes old), checking if conda itself needs update"
        fi
        return 1  # Update not needed
    fi

}

# Conda update function
zsu_update_conda() {
    VERBOSE=${1:-false}
    SKIP_CONDA=${2:-false}
    QUIET=${3:-false}
    FORCE_CONDA_UPDATE=${4:-false}

    if [[ "${SKIP_CONDA}" == true ]]; then
        zsu_print_status "Skipping Conda updates"
        return 0
    fi
    
    # Use dynamic conda detection
    if [[ -z "${CONDA_CMD}" ]]; then
        zsu_print_warning "Conda not found, skipping conda updates"
        return 0
    fi
    
    zsu_print_status "Starting Conda updates..."
    
    # Debug: Show conda info
    if [[ "${VERBOSE}" == true ]]; then
        zsu_print_status "Using conda at: ${CONDA_CMD}"
        zsu_print_status "Conda version: $(${CONDA_CMD} --version 2>/dev/null || echo 'unknown')"
    fi
    
    # Only update conda if needed (unless forced)
    if [[ "${FORCE_CONDA_UPDATE}" == true ]] || zsu_conda_update_needed; then
        # Check if mamba is available in the same environment
        local mamba_available=false
        local conda_dir=$(dirname "${CONDA_CMD}")
        if [[ -x "${conda_dir}/mamba" ]]; then
            mamba_available=true
        fi
        
        if [[ "${mamba_available}" == true ]]; then
            run_cmd "${CONDA_CMD} update conda mamba --yes" "Updating conda and mamba"
        else
            run_cmd "${CONDA_CMD} update conda --yes" "Updating conda"
        fi
        
        run_cmd "${CONDA_CMD} clean --all --yes" "Cleaning conda cache"
    else
        zsu_print_status "Conda is recently updated, skipping conda update"
    fi
    
    zsu_print_success "Conda updates completed"

    return 0

}

export CONDA_CMD
export CONDA_BASE
export CONDA_ENVS_DIR
