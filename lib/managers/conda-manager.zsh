#!/bin/zsh
# Conda manager for zsh-system-update

# Dependency guard for output utilities
# Load output utilities in isolated scope
_zsu_load_output_utils() {
    if ! typeset -f zsu_print_status >/dev/null 2>&1; then
        local module="lib/utils/output.zsh"
        local plugin_dir="${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins/zsh-system-update"
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
        local plugin_dir="${TEST_PLUGIN_DIR:-${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins/zsh-system-update}"
        local cache_module_path="${plugin_dir}/${cache_module}"
        source "${cache_module_path}"
    fi
    unset -f _zsu_load_cache_utils
}
_zsu_load_cache_utils

# Conda detection variables
CONDA_CMD=""
CONDA_BASE=""
CONDA_ENVS_DIR=""

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
            # Convert PATH to array using bash-compatible syntax
            IFS=':' read -ra path_entries <<< "$PATH"
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
    local VERBOSE="${1:-false}"
    
    # Use detected conda base directory
    if [[ -z "$CONDA_BASE" ]]; then
        return 0  # No conda installation found, skip but don't error
    fi

    if zsu_cache_needs_update "conda"; then
        if [[ "$VERBOSE" == true ]]; then
            local time_since=$(zsu_cache_time_since_update_human "conda")
            zsu_print_status "Last conda update was ${time_since}, updating..."
        fi
        return 0  # Update needed
    else
        if [[ "$VERBOSE" == true ]]; then
            local time_since=$(zsu_cache_time_since_update_human "conda")
            zsu_print_status "Conda was updated recently (${time_since}), skipping update"
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
    if [[ "${FORCE_CONDA_UPDATE}" == true ]] || zsu_conda_update_needed "${VERBOSE}"; then
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
