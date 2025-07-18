#!/bin/zsh
# Output utilities for zsh-system-update

# Ensure colors are available
if [[ -z "$fg" ]]; then
    autoload -U colors && colors
fi

# Output functions
zsu_print_status() {
    print -P "%F{blue}[INFO]%f $1"
}

zsu_print_success() {
    print -P "%F{green}[SUCCESS]%f $1"
}

zsu_print_warning() {    # Fixed: was zsh_print_warning
    print -P "%F{yellow}[WARNING]%f $1"
}

zsu_print_error() {
    print -P "%F{red}[ERROR]%f $1"
}

zsu_run_cmd() {
    local cmd="$1"
    local description="$2"
    local dry_run="$3"
    local verbose="$4"
    local quiet="$5"

    if [[ "$verbose" == true ]]; then    # Fixed: added space before ]]
        zsu_print_status "Running: $cmd"
    elif [[ -n "$description" ]]; then
        zsu_print_status "$description"
    fi

    if [[ "$dry_run" == true ]]; then    # Fixed: added space before ]]
        echo "Dry run: $cmd"
        return 0
    fi

    if [[ "$quiet" == true ]]; then
        eval "$cmd" >/dev/null 2>&1
    elif [[ "$verbose" == false && "$cmd" =~ "apt " ]]; then
        eval "$cmd" 2>/dev/null
    else
        eval "$cmd"
    fi
}
