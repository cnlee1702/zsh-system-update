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
    
    # Find and update pip in conda environments
    local env_count=0
    
    if [[ -n "${CONDA_ENVS_DIR}" && -d "${CONDA_ENVS_DIR}" ]]; then
        for env_path in "${CONDA_ENVS_DIR}"/*; do
            local env_name=$(basename "${env_path}")
            ((env_count++))

            if [[ "${DRY_RUN}" == true ]]; then
                echo "DRY RUN: ${CONDA_CMD} run -n ${env_name} python -m pip install --upgrade pip"
            elif [[ -d "${env_path}" && -f "${env_path}/bin/pip" ]]; then
                
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
        done 
        zsu_print_status "Updated pip in ${env_count} conda environments"
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
