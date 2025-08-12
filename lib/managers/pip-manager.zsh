#!/bin/zsh
# Pip manager for zsh-system-update

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

# Pip update function
zsu_update_pip() {
    VERBOSE=${1:-false}
    SKIP_PIP=${2:-false}
    QUIET=${3:-false}
    DRY_RUN=${4:-false}

    if [[ "${SKIP_PIP}" == true ]]; then
        zsu_print_status "Skipping pip updates"
        return 0
    fi
    
    zsu_print_status "Starting pip updates..."

    # Update pip in base environment
    if zsu_cache_needs_update "pip" "base"; then
        if [[ "${VERBOSE}" == true ]]; then
            local time_since=$(zsu_cache_time_since_update_human "pip" "base")
            zsu_print_status "Base pip was last updated ${time_since}, updating..."
        fi
        
        if [[ "${DRY_RUN}" == true ]]; then
            echo "DRY RUN: python -m pip install --upgrade pip"
        elif [[ "${QUIET}" == true ]]; then
            run_cmd "python -m pip install --quiet --upgrade pip"
        elif [[ "${VERBOSE}" == true ]]; then
            zsu_print_status "Updating pip in base environment"
            run_cmd "python -m pip install --upgrade pip --verbose" "Upgrading pip in base environment"
        else
            run_cmd "python -m pip install --upgrade pip" "Upgrading pip in base environment"
        fi
        
        zsu_cache_touch "pip" "base"
    else
        if [[ "${VERBOSE}" == true ]]; then
            local time_since=$(zsu_cache_time_since_update_human "pip" "base")
            zsu_print_status "Base pip was updated recently (${time_since}), skipping"
        fi
    fi
    
    # Find and update pip in conda environments
    local env_count=0
    
    if [[ -n "${CONDA_ENVS_DIR}" && -d "${CONDA_ENVS_DIR}" ]]; then
        for env_path in "${CONDA_ENVS_DIR}"/*; do
            local env_name=$(basename "${env_path}")
            
            if [[ -d "${env_path}" && -f "${env_path}/bin/pip" ]]; then
                if zsu_cache_needs_update "pip" "${env_name}"; then
                    ((env_count++))
                    
                    if [[ "${VERBOSE}" == true ]]; then
                        local time_since=$(zsu_cache_time_since_update_human "pip" "${env_name}")
                        zsu_print_status "Pip in ${env_name} was last updated ${time_since}, updating..."
                    fi

                    if [[ "${DRY_RUN}" == true ]]; then
                        echo "DRY RUN: ${CONDA_CMD} run -n ${env_name} python -m pip install --upgrade pip"
                    else
                        # Use the detected conda command
                        pip_cmd="${CONDA_CMD} run -n ${env_name} python -m pip install --upgrade pip"

                        if [[ "${VERBOSE}" == true ]]; then
                            zsu_print_status "Updating pip in environment: ${env_name}"
                            run_cmd "${pip_cmd} --verbose" "Upgrading pip in ${env_name}"
                        elif [[ "${QUIET}" == true ]]; then
                            run_cmd "${pip_cmd} --quiet"
                        else
                            run_cmd "${pip_cmd}" "Upgrading pip in ${env_name}"
                        fi
                    fi
                    
                    zsu_cache_touch "pip" "${env_name}"
                else
                    if [[ "${VERBOSE}" == true ]]; then
                        local time_since=$(zsu_cache_time_since_update_human "pip" "${env_name}")
                        zsu_print_status "Pip in ${env_name} was updated recently (${time_since}), skipping"
                    fi
                fi
            fi
        done 
        
        if [[ $env_count -gt 0 ]]; then
            zsu_print_status "Updated pip in ${env_count} conda environments"
        else
            zsu_print_status "All pip installations in conda environments are up to date"
        fi
    else
        zsu_print_warning "No conda environments directory found"
    fi
    
    # Clean pip cache once at the end
    if [[ "${DRY_RUN}" == true ]]; then
        echo "DRY RUN: python -m pip cache purge"
    elif [[ "${VERBOSE}" == true ]]; then
        zsu_print_status "Purging pip cache"
        run_cmd "python -m pip cache purge" "Cleaning pip cache"
    else
        run_cmd "python -m pip cache purge" "Cleaning pip cache"
    fi
    
    zsu_print_success "Pip updates completed"

    return 0

}
