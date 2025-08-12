#!/bin/zsh
# Cache utilities for zsh-system-update
# Shared interface for managing last run timestamps and cache thresholds

# Default cache thresholds (in seconds)
ZSU_CACHE_THRESHOLD_APT=${ZSU_CACHE_THRESHOLD_APT:-3600}      # 1 hour
ZSU_CACHE_THRESHOLD_CONDA=${ZSU_CACHE_THRESHOLD_CONDA:-604800}  # 1 week  
ZSU_CACHE_THRESHOLD_FLATPAK=${ZSU_CACHE_THRESHOLD_FLATPAK:-7200}  # 2 hours
ZSU_CACHE_THRESHOLD_PIP=${ZSU_CACHE_THRESHOLD_PIP:-604800}    # 1 week

# Cache directory
ZSU_CACHE_DIR="${ZSU_CACHE_DIR:-${HOME}/.cache/zsh-system-update}"

# Initialize cache directory if it doesn't exist
zsu_cache_init() {
    [[ ! -d "$ZSU_CACHE_DIR" ]] && mkdir -p "$ZSU_CACHE_DIR" 2>/dev/null
}

# Get cache threshold for a manager
# Usage: zsu_get_cache_threshold <manager_name>
zsu_get_cache_threshold() {
    local manager="$1"
    # Use bash-compatible uppercase conversion
    local threshold_var="ZSU_CACHE_THRESHOLD_$(echo "${manager}" | tr '[:lower:]' '[:upper:]')"
    
    # Use eval for bash compatibility
    local threshold_val
    eval "threshold_val=\$${threshold_var}"
    if [[ -n "$threshold_val" ]]; then
        echo "$threshold_val"
    else
        echo "3600"  # Default to 1 hour
    fi
}

# Check if manager needs update based on cache
# Usage: zsu_cache_needs_update <manager_name> [environment_id]
# Returns 0 if update needed, 1 if cache is fresh
zsu_cache_needs_update() {
    local manager="$1"
    local env_id="${2:-}"
    # Use bash-compatible uppercase conversion
    local force_var="FORCE_$(echo "${manager}" | tr '[:lower:]' '[:upper:]')_UPDATE"
    
    # If force update is enabled, always return needs update
    # Use eval for bash compatibility instead of ${(P)...} zsh syntax
    local force_val
    eval "force_val=\$${force_var}"
    if [[ "$force_val" == true ]]; then
        return 0
    fi
    
    zsu_cache_init
    
    local cache_file="${ZSU_CACHE_DIR}/${manager}"
    [[ -n "$env_id" ]] && cache_file="${cache_file}_${env_id}"
    
    local threshold=$(zsu_get_cache_threshold "$manager")
    local current_time="${ZSU_CURRENT_TIME:-$(date +%s)}"
    
    if [[ ! -f "$cache_file" ]]; then
        return 0  # No cache file, update needed
    fi
    
    local last_update=$(stat -c %Y "$cache_file" 2>/dev/null || echo 0)
    local time_diff=$((current_time - last_update))
    
    if [[ $time_diff -gt $threshold ]]; then
        return 0  # Cache expired, update needed
    else
        return 1  # Cache is fresh, no update needed
    fi
}

# Update cache timestamp for manager
# Usage: zsu_cache_touch <manager_name> [environment_id]
zsu_cache_touch() {
    local manager="$1"
    local env_id="${2:-}"
    
    # Skip cache update in dry-run mode
    if [[ "${DRY_RUN}" == true ]]; then
        return 0
    fi
    
    zsu_cache_init
    
    local cache_file="${ZSU_CACHE_DIR}/${manager}"
    [[ -n "$env_id" ]] && cache_file="${cache_file}_${env_id}"
    
    touch "$cache_file" 2>/dev/null
}

# Get time since last update for manager
# Usage: zsu_cache_time_since_update <manager_name> [environment_id]
# Returns time in seconds since last update, or -1 if never updated
zsu_cache_time_since_update() {
    local manager="$1" 
    local env_id="${2:-}"
    
    zsu_cache_init
    
    local cache_file="${ZSU_CACHE_DIR}/${manager}"
    [[ -n "$env_id" ]] && cache_file="${cache_file}_${env_id}"
    
    if [[ ! -f "$cache_file" ]]; then
        echo "-1"
        return
    fi
    
    local last_update=$(stat -c %Y "$cache_file" 2>/dev/null || echo 0)
    local current_time="${ZSU_CURRENT_TIME:-$(date +%s)}"
    echo $((current_time - last_update))
}

# Get human-readable time since last update
# Usage: zsu_cache_time_since_update_human <manager_name> [environment_id]
zsu_cache_time_since_update_human() {
    local manager="$1"
    local env_id="${2:-}"
    local time_diff=$(zsu_cache_time_since_update "$manager" "$env_id")
    
    if [[ $time_diff -eq -1 ]]; then
        echo "never"
    elif [[ $time_diff -lt 60 ]]; then
        echo "${time_diff} seconds ago"
    elif [[ $time_diff -lt 3600 ]]; then
        echo "$((time_diff / 60)) minutes ago"
    else
        echo "$((time_diff / 3600)) hours ago"
    fi
}

# Clean old cache files (older than 30 days)
# Usage: zsu_cache_cleanup
zsu_cache_cleanup() {
    zsu_cache_init
    find "$ZSU_CACHE_DIR" -type f -mtime +30 -delete 2>/dev/null || true
}

# List all cache entries with their timestamps
# Usage: zsu_cache_list
zsu_cache_list() {
    zsu_cache_init
    
    if [[ ! -d "$ZSU_CACHE_DIR" ]] || [[ -z "$(ls -A "$ZSU_CACHE_DIR" 2>/dev/null)" ]]; then
        echo "No cache entries found."
        return
    fi
    
    echo "Cache entries:"
    for cache_file in "$ZSU_CACHE_DIR"/*; do
        if [[ -f "$cache_file" ]]; then
            local filename=$(basename "$cache_file")
            local timestamp=$(stat -c %Y "$cache_file" 2>/dev/null || echo 0)
            local human_time=$(date -d "@${timestamp}" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "unknown")
            echo "  ${filename}: ${human_time}"
        fi
    done
}