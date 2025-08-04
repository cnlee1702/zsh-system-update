#!/bin/bash

# Shared test utilities for zsh-system-update test suite
# This file provides common functions and setup for all test files

# Colors for test output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters (initialize if not already set)
TESTS_RUN=${TESTS_RUN:-0}
TESTS_PASSED=${TESTS_PASSED:-0}
TESTS_FAILED=${TESTS_FAILED:-0}

# Test helper functions
print_test_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

print_test() {
    echo -e "${YELLOW}Testing: $1${NC}"
    ((TESTS_RUN++))
}

assert_success() {
    local description="$1"
    local command="$2"
    
    print_test "$description"
    
    if eval "$command" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS${NC}: $description"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: $description"
        echo "  Command: $command"
        ((TESTS_FAILED++))
    fi
}

assert_failure() {
    local description="$1"
    local command="$2"
    
    print_test "$description"
    
    if ! eval "$command" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS${NC}: $description"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: $description"
        echo "  Command: $command (should have failed)"
        ((TESTS_FAILED++))
    fi
}

assert_contains() {
    local description="$1"
    local command="$2"
    local expected="$3"
    
    print_test "$description"
    
    local output
    output=$(eval "$command" 2>&1)
    
    if echo "$output" | grep -q "$expected"; then
        echo -e "${GREEN}✓ PASS${NC}: $description"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: $description"
        echo "  Expected to contain: $expected"
        echo "  Actual output: $output"
        ((TESTS_FAILED++))
    fi
}

assert_not_contains() {
    local description="$1"
    local command="$2"
    local not_expected="$3"
    
    print_test "$description"
    
    local output
    output=$(eval "$command" 2>&1)
    
    if ! echo "$output" | grep -q "$not_expected"; then
        echo -e "${GREEN}✓ PASS${NC}: $description"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: $description"
        echo "  Should not contain: $not_expected"
        echo "  Actual output: $output"
        ((TESTS_FAILED++))
    fi
}

assert_equals() {
    local description="$1"
    local command="$2"
    local expected="$3"
    
    print_test "$description"
    
    local output
    output=$(eval "$command" 2>&1)
    
    if [[ "$output" == "$expected" ]]; then
        echo -e "${GREEN}✓ PASS${NC}: $description"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: $description"
        echo "  Expected: $expected"
        echo "  Actual: $output"
        ((TESTS_FAILED++))
    fi
}

# For manual tests that need custom logic
run_test() {
    local description="$1"
    print_test "$description"
}

# Mock timestamp for cache testing
mock_timestamp() {
    local hours_ago="$1"
    # Calculate seconds ago (more portable than date -d)
    local seconds_ago=$((${hours_ago%.*} * 3600))
    local current_time=$(date +%s)
    echo $((current_time - seconds_ago))
}

# Create mock cache file with specific timestamp
create_mock_cache() {
    local cache_file="$1"
    local hours_old="$2"
    
    mkdir -p "$(dirname "$cache_file")"
    touch "$cache_file"
    
    # Calculate timestamp more reliably
    local current_time=$(date +%s)
    local hours_in_seconds=$((${hours_old%.*} * 3600))
    local target_time=$((current_time - hours_in_seconds))
    
    # Use touch with explicit timestamp
    touch -d "@$target_time" "$cache_file" 2>/dev/null || {
        # Fallback for systems where touch -d doesn't work
        touch "$cache_file"
        # Try alternative timestamp format
        local timestamp=$(date -d "@$target_time" '+%Y%m%d%H%M.%S' 2>/dev/null) || {
            # Ultimate fallback - just touch the file
            echo "Warning: Could not set timestamp for mock cache file" >&2
        }
        [[ -n "$timestamp" ]] && touch -t "$timestamp" "$cache_file" 2>/dev/null
    }
}

# Setup minimal test environment for unit tests
setup_unit_test_env() {
    # Create temporary directory for testing
    local test_dir
    test_dir=$(mktemp -d)
    export UNIT_TEST_DIR="$test_dir"
    export UNIT_HOME="$UNIT_TEST_DIR/home"
    mkdir -p "$UNIT_HOME"
    
    # Set up minimal cache directories
    mkdir -p "$UNIT_HOME/.cache/zsh-system-update"
    mkdir -p "$UNIT_HOME/.conda"
    mkdir -p "$UNIT_HOME/.cache/flatpak"
    
    echo -e "${GREEN}✓${NC} Unit test environment setup complete"
}

# Cleanup unit test environment
cleanup_unit_test_env() {
    if [[ -n "$UNIT_TEST_DIR" && -d "$UNIT_TEST_DIR" ]]; then
        rm -rf "$UNIT_TEST_DIR"
        echo -e "${GREEN}✓${NC} Unit test environment cleaned"
    fi
}

# Load plugin modules for unit testing
load_test_plugin() {
    local plugin_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    export TEST_PLUGIN_DIR="$plugin_dir"
    
    # Mock zsh-specific functions and variables for bash compatibility
    if ! command -v autoload >/dev/null 2>&1; then
        autoload() {
            # Mock autoload function - just return success
            return 0
        }
        export -f autoload
    fi
    
    # Mock colors command
    if ! command -v colors >/dev/null 2>&1; then
        colors() {
            # Mock colors function - just return success
            return 0
        }
        export -f colors
    fi
    
    # Mock zsh color variables
    export fg_blue="\033[34m"
    export fg_green="\033[32m"
    export fg_yellow="\033[33m"
    export fg_red="\033[31m"
    export reset_color="\033[0m"
    export fg=(
        [blue]="\033[34m"
        [green]="\033[32m"
        [yellow]="\033[33m"
        [red]="\033[31m"
    )
    
    # Mock print command for bash (zsh's print -P)
    if ! command -v print >/dev/null 2>&1; then
        print() {
            local arg
            local use_colors=false
            
            # Handle -P flag for prompt expansion
            if [[ "$1" == "-P" ]]; then
                shift
                use_colors=true
            fi
            
            # Simple color substitution for testing
            local output="$*"
            if [[ "$use_colors" == true ]]; then
                output="${output//%F{blue}/\033[34m}"
                output="${output//%F{green}/\033[32m}"
                output="${output//%F{yellow}/\033[33m}"
                output="${output//%F{red}/\033[31m}"
                output="${output//%f/\033[0m}"
            fi
            
            echo -e "$output"
        }
        export -f print
    fi
    
    # Define zsu_import function for testing
    zsu_import() {
        local module="$1"
        local module_path="${TEST_PLUGIN_DIR}/${module}"
        
        if [[ -f "$module_path" ]]; then
            source "$module_path"
            return 0
        else
            echo "ERROR: Cannot load module: $module" >&2
            return 1
        fi
    }
    
    # Import utility modules
    if ! zsu_import "lib/utils/output.zsh"; then
        echo -e "${RED}✗${NC} Failed to load output utilities"
        return 1
    fi
    
    echo -e "${GREEN}✓${NC} Test plugin modules loaded"
}

# Mock sudo commands for testing
mock_sudo() {
    local command="$1"
    shift
    echo "MOCK_SUDO: $command $*"
}

# Mock time-dependent functions
mock_current_time() {
    echo "${MOCK_CURRENT_TIME:-$(date +%s)}"
}

# Set mock time for testing
set_mock_time() {
    export MOCK_CURRENT_TIME="$1"
}

# Print test summary for unit tests
print_unit_test_summary() {
    local test_name="$1"
    
    echo -e "\n${BLUE}=== $test_name Test Summary ===${NC}"
    echo "Tests run: $TESTS_RUN"
    echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}✓ All $test_name tests passed!${NC}"
        return 0
    else
        echo -e "\n${RED}✗ Some $test_name tests failed${NC}"
        return 1
    fi
}

# Export functions for use in other test files
export -f print_test_header print_test assert_success assert_failure assert_contains
export -f assert_not_contains assert_equals run_test mock_timestamp create_mock_cache
export -f setup_unit_test_env cleanup_unit_test_env load_test_plugin mock_sudo
export -f mock_current_time set_mock_time print_unit_test_summary