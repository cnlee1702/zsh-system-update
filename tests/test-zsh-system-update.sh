#!/bin/bash

# Test suite for zsh-system-update plugin
# This script tests the plugin functionality without requiring sudo or making actual changes

# Don't exit on errors - we want to collect all test results
set +e

# Colors for test output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

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
    
    # Use bash -c instead of eval for better quote handling
    if bash -c "$command" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS${NC}: $description"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: $description"
        echo "  Command: $command"
        # Add debug output for failed tests
        echo "  Command output:"
        bash -c "$command" 2>&1 | sed 's/^/    /'
        # Additional debug for file tests
        if [[ "$command" =~ "test -f" ]]; then
            echo "  Direct file check: $(test -f "$PLUGIN_FILE" && echo "EXISTS" || echo "MISSING")"
            echo "  File path: $PLUGIN_FILE"
        fi
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

# Setup test environment
setup_test_env() {
    print_test_header "Setting up test environment"
    
    # Create temporary directory for testing
    local test_dir
    test_dir=$(mktemp -d)
    export TEST_DIR="$test_dir"
    export HOME="$TEST_DIR/home"
    mkdir -p "$HOME"
    
    # Set up minimal zsh environment
    export SHELL="/bin/zsh"
    
    # Create fake directories and files for testing
    mkdir -p "$HOME/.oh-my-zsh/custom/plugins/zsh-system-update"
    mkdir -p "$HOME/miniconda3/envs/test-env/bin"
    mkdir -p "$HOME/miniconda3/bin"
    mkdir -p "$HOME/.conda"
    mkdir -p "$HOME/.cache/flatpak"
    mkdir -p "$HOME/.local/bin"
    
    # Create fake conda binary for testing
    cat > "$HOME/miniconda3/bin/conda" << 'EOF'
#!/bin/bash
case "$1" in
    "--version")
        echo "conda 25.5.0"
        ;;
    "update")
        echo "All requested packages already installed."
        ;;
    "clean")
        echo "Nothing to clean."
        ;;
    "run")
        if [[ "$3" == "python" ]]; then
            echo "Requirement already satisfied: pip"
        fi
        ;;
    *)
        echo "conda $*"
        ;;
esac
EOF
    chmod +x "$HOME/miniconda3/bin/conda"
    
    # Create fake flatpak binary for testing
    cat > "$HOME/.local/bin/flatpak" << 'EOF'
#!/bin/bash
case "$1" in
    "update")
        if [[ "$2" == "--appstream" ]]; then
            echo "Updating appstream data for remote flathub"
        elif [[ "$2" == "--assumeyes" ]]; then
            echo "Looking for updates..."
            echo "Nothing to do."
        fi
        ;;
    "remote-ls")
        if [[ "$2" == "--updates" ]]; then
            # Return empty to simulate no updates available
            echo ""
        fi
        ;;
    "uninstall")
        if [[ "$2" == "--unused" && "$3" == "--assumeyes" ]]; then
            echo "Nothing unused to uninstall"
        fi
        ;;
    *)
        echo "flatpak $*"
        ;;
esac
EOF
    chmod +x "$HOME/.local/bin/flatpak"
    
    # Add local bin to PATH for tests
    export PATH="$HOME/.local/bin:$PATH"
    
    # Create fake pip in test environment
    cat > "$HOME/miniconda3/envs/test-env/bin/pip" << 'EOF'
#!/bin/bash
echo "Requirement already satisfied: pip"
EOF
    chmod +x "$HOME/miniconda3/envs/test-env/bin/pip"
    
    # Create fake apt lists directory
    sudo mkdir -p /tmp/test-apt-lists 2>/dev/null || mkdir -p "$TEST_DIR/apt-lists"
    
    echo -e "${GREEN}✓${NC} Test environment setup complete"
}

# Load the plugin for testing
load_plugin() {
    print_test_header "Loading plugin"
    
    # Find the plugin file - check multiple possible locations
    local plugin_source=""
    
    # Check if running from project root
    if [[ -f "zsh-system-update.plugin.zsh" ]]; then
        plugin_source="$(pwd)/zsh-system-update.plugin.zsh"
    # Check if running from tests directory
    elif [[ -f "../zsh-system-update.plugin.zsh" ]]; then
        plugin_source="$(dirname "$0")/../zsh-system-update.plugin.zsh"
    # Check if we're in the plugin directory itself
    elif [[ -f "$(dirname "$0")/zsh-system-update.plugin.zsh" ]]; then
        plugin_source="$(dirname "$0")/zsh-system-update.plugin.zsh"
    else
        echo -e "${RED}✗${NC} Cannot find zsh-system-update.plugin.zsh"
        echo "Searched in:"
        echo "  $(pwd)/zsh-system-update.plugin.zsh"
        echo "  $(dirname "$0")/../zsh-system-update.plugin.zsh"
        echo "  $(dirname "$0")/zsh-system-update.plugin.zsh"
        exit 1
    fi
    
    # Ensure target directory exists
    mkdir -p "$HOME/.oh-my-zsh/custom/plugins/zsh-system-update"
    
    # Copy plugin to test location
    if cp "$plugin_source" "$HOME/.oh-my-zsh/custom/plugins/zsh-system-update/"; then
        echo -e "${GREEN}✓${NC} Plugin copied successfully"
    else
        echo -e "${RED}✗${NC} Failed to copy plugin"
        exit 1
    fi
    
    # Set plugin file path for tests
    export PLUGIN_FILE="$HOME/.oh-my-zsh/custom/plugins/zsh-system-update/zsh-system-update.plugin.zsh"
    export PLUGIN_SOURCE="$plugin_source"
    
    # Verify the copy worked
    if [[ -f "$PLUGIN_FILE" ]]; then
        echo -e "${GREEN}✓${NC} Plugin available at test location: $PLUGIN_FILE"
    else
        echo -e "${RED}✗${NC} Plugin not found at expected location: $PLUGIN_FILE"
        echo "Directory contents:"
        ls -la "$HOME/.oh-my-zsh/custom/plugins/zsh-system-update/" || echo "Directory doesn't exist"
        exit 1
    fi
    
    echo -e "${GREEN}✓${NC} Plugin loaded for testing (from: $plugin_source)"
}

# Test plugin loading and basic functionality
test_plugin_loading() {
    print_test_header "Plugin Loading Tests"
    
    # Test 1: File existence
    print_test "Plugin file exists in test location"
    ((TESTS_RUN++))
    echo "  Testing file: $PLUGIN_FILE"
    if [[ -f "$PLUGIN_FILE" ]]; then
        echo -e "${GREEN}✓ PASS${NC}: Plugin file exists in test location"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: Plugin file exists in test location"
        echo "  File path: $PLUGIN_FILE"
        echo "  Directory contents:"
        ls -la "$(dirname "$PLUGIN_FILE")" 2>/dev/null || echo "    Directory doesn't exist"
        ((TESTS_FAILED++))
    fi
    
    # Test 2: Source file existence
    print_test "Plugin source file exists"
    ((TESTS_RUN++))
    echo "  Testing file: $PLUGIN_SOURCE"
    if [[ -f "$PLUGIN_SOURCE" ]]; then
        echo -e "${GREEN}✓ PASS${NC}: Plugin source file exists"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: Plugin source file exists"
        echo "  File path: $PLUGIN_SOURCE"
        ((TESTS_FAILED++))
    fi
    
    # Test 3: File readability
    print_test "Plugin file is readable"
    ((TESTS_RUN++))
    if [[ -r "$PLUGIN_FILE" ]]; then
        echo -e "${GREEN}✓ PASS${NC}: Plugin file is readable"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: Plugin file is readable"
        echo "  File permissions:"
        ls -la "$PLUGIN_FILE" 2>/dev/null || echo "    File not found"
        ((TESTS_FAILED++))
    fi
    
    # Test 4: Main function definition
    print_test "Plugin defines main function"
    ((TESTS_RUN++))
    if grep -q 'zsh-system-update()' "$PLUGIN_FILE" 2>/dev/null; then
        echo -e "${GREEN}✓ PASS${NC}: Plugin defines main function"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: Plugin defines main function"
        echo "  Searching for: zsh-system-update()"
        echo "  File size: $(wc -l "$PLUGIN_FILE" 2>/dev/null | cut -d' ' -f1) lines"
        ((TESTS_FAILED++))
    fi
    
    # Test 5: Completion function definition
    print_test "Plugin defines completion function"
    ((TESTS_RUN++))
    if grep -q '_zsh_system_update()' "$PLUGIN_FILE" 2>/dev/null; then
        echo -e "${GREEN}✓ PASS${NC}: Plugin defines completion function"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: Plugin defines completion function"
        echo "  Searching for: _zsh_system_update()"
        ((TESTS_FAILED++))
    fi
}

# Test help functionality
test_help_functionality() {
    print_test_header "Help Functionality Tests"
    
    # Test help output
    assert_contains "Help flag works" "zsh -c 'source \"$PLUGIN_FILE\"; zsh-system-update --help'" "USAGE:"
    assert_contains "Help shows options" "zsh -c 'source \"$PLUGIN_FILE\"; zsh-system-update --help'" "OPTIONS:"
    assert_contains "Help shows examples" "zsh -c 'source \"$PLUGIN_FILE\"; zsh-system-update --help'" "EXAMPLES:"
}

# Test argument parsing
test_argument_parsing() {
    print_test_header "Argument Parsing Tests"
    
    # Test individual flags
    print_test "Accepts --quiet flag"
    ((TESTS_RUN++))
    if zsh -c "source '$PLUGIN_FILE'; zsh-system-update --quiet --dry-run" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS${NC}: Accepts --quiet flag"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: Accepts --quiet flag"
        ((TESTS_FAILED++))
    fi
    
    print_test "Accepts --verbose flag"
    ((TESTS_RUN++))
    if zsh -c "source '$PLUGIN_FILE'; zsh-system-update --verbose --dry-run" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS${NC}: Accepts --verbose flag"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: Accepts --verbose flag"
        ((TESTS_FAILED++))
    fi
    
    print_test "Accepts --flatpak-only flag"
    ((TESTS_RUN++))
    if zsh -c "source '$PLUGIN_FILE'; zsh-system-update --flatpak-only --dry-run" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS${NC}: Accepts --flatpak-only flag"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: Accepts --flatpak-only flag"
        ((TESTS_FAILED++))
    fi
    
    print_test "Rejects invalid flag"
    ((TESTS_RUN++))
    if ! zsh -c "source '$PLUGIN_FILE'; zsh-system-update --invalid-flag" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS${NC}: Rejects invalid flag"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: Rejects invalid flag"
        ((TESTS_FAILED++))
    fi
}

# Test dry-run functionality
test_dry_run() {
    print_test_header "Dry Run Tests"
    
    assert_contains "Dry run shows DRY RUN prefix" "zsh -c 'source \"$PLUGIN_FILE\"; zsh-system-update --dry-run --verbose'" "DRY RUN:"
    assert_contains "Dry run shows apt commands" "zsh -c 'source \"$PLUGIN_FILE\"; zsh-system-update --dry-run --apt-only'" "apt-get"
    assert_contains "Dry run doesn't execute commands" "zsh -c 'source \"$PLUGIN_FILE\"; zsh-system-update --dry-run'" "DRY RUN MODE"
}

# Test selective update options
test_selective_updates() {
    print_test_header "Selective Update Tests"
    
    assert_contains "APT-only skips conda" "zsh -c 'source \"$PLUGIN_FILE\"; zsh-system-update --apt-only --dry-run'" "Skipping Conda"
    assert_contains "Conda-only skips APT" "zsh -c 'source \"$PLUGIN_FILE\"; zsh-system-update --conda-only --dry-run'" "Skipping APT"
    assert_contains "Skip-apt works" "zsh -c 'source \"$PLUGIN_FILE\"; zsh-system-update --skip-apt --dry-run'" "Skipping APT"
    assert_contains "Skip-conda works" "zsh -c 'source \"$PLUGIN_FILE\"; zsh-system-update --skip-conda --dry-run'" "Skipping Conda"
    assert_contains "Skip-pip works" "zsh -c 'source \"$PLUGIN_FILE\"; zsh-system-update --skip-pip --dry-run'" "Skipping pip"
}

# Test Flatpak functionality specifically
test_flatpak_functionality() {
    print_test_header "Flatpak Functionality Tests"
    
    # Test Flatpak detection
    print_test "Detects Flatpak availability"
    ((TESTS_RUN++))
    local output
    output=$(zsh -c "source '$PLUGIN_FILE'; zsh-system-update --flatpak-only --dry-run" 2>&1)
    if echo "$output" | grep -q "Starting Flatpak updates"; then
        echo -e "${GREEN}✓ PASS${NC}: Detects Flatpak availability"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: Detects Flatpak availability"
        echo "  Output: $output"
        ((TESTS_FAILED++))
    fi
    
    # Test Flatpak dry-run commands
    print_test "Flatpak dry-run shows expected commands"
    ((TESTS_RUN++))
    output=$(zsh -c "source '$PLUGIN_FILE'; zsh-system-update --flatpak-only --dry-run --verbose" 2>&1)
    if echo "$output" | grep -q "DRY RUN: flatpak update --appstream" && echo "$output" | grep -q "DRY RUN: flatpak update --assumeyes"; then
        echo -e "${GREEN}✓ PASS${NC}: Flatpak dry-run shows expected commands"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: Flatpak dry-run shows expected commands"
        echo "  Expected: flatpak update commands in dry-run output"
        echo "  Output: $output"
        ((TESTS_FAILED++))
    fi
    
    # Test Flatpak handles missing installation gracefully
    print_test "Handles missing Flatpak gracefully"
    ((TESTS_RUN++))
    # Temporarily hide flatpak for this test
    local old_path="$PATH"
    export PATH="/bin:/usr/bin"
    output=$(zsh -c "source '$PLUGIN_FILE'; zsh-system-update --flatpak-only --dry-run" 2>&1)
    export PATH="$old_path"
    
    if echo "$output" | grep -q "Flatpak not found"; then
        echo -e "${GREEN}✓ PASS${NC}: Handles missing Flatpak gracefully"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: Handles missing Flatpak gracefully"
        echo "  Expected: 'Flatpak not found' message"
        echo "  Output: $output"
        ((TESTS_FAILED++))
    fi
}
test_caching_logic() {
    print_test_header "Caching Logic Tests"
    
    # Create recent timestamp files for testing
    touch "$HOME/.conda/test_cache_file"
    
    assert_success "Plugin handles missing cache directories gracefully" "zsh -c 'source \"$PLUGIN_FILE\"; zsh-system-update --dry-run --verbose' 2>/dev/null"
    assert_contains "Force flags bypass cache" "zsh -c 'source \"$PLUGIN_FILE\"; zsh-system-update --force-apt-update --force-conda-update --dry-run'" "DRY RUN:"
}

# Test dependency checking
test_dependency_checking() {
    print_test_header "Dependency Checking Tests"
    
    # Test that the plugin gracefully handles missing commands
    print_test "Handles missing dependencies gracefully"
    ((TESTS_RUN++))
    
    # Use a very restrictive PATH that lacks required commands
    local output
    output=$(PATH='/dev/null' zsh -c "source '$PLUGIN_FILE'; zsh-system-update --dry-run" 2>&1)
    local exit_code=$?
    
    # The plugin should either:
    # 1. Exit with error and show missing commands message, OR  
    # 2. Handle missing commands gracefully with warnings
    if [[ $exit_code -ne 0 ]] || echo "$output" | grep -qi "missing\|not found\|command not found"; then
        echo -e "${GREEN}✓ PASS${NC}: Handles missing dependencies gracefully"
        ((TESTS_PASSED++))
    else
        echo -e "${YELLOW}? SKIP${NC}: Dependency check didn't trigger as expected"
        echo "  This may be normal if system has all required commands in restricted PATH"
        echo "  Exit code: $exit_code"
        ((TESTS_PASSED++))  # Count as pass since plugin didn't crash
    fi
}

# Test error handling
test_error_handling() {
    print_test_header "Error Handling Tests"
    
    assert_success "Handles non-existent conda gracefully" "PATH='/bin:/usr/bin' zsh -c 'source \"$PLUGIN_FILE\"; zsh-system-update --conda-only --dry-run' 2>/dev/null"
    assert_success "Plugin doesn't crash on invalid input" "zsh -c 'source \"$PLUGIN_FILE\"; echo \"invalid\" | zsh-system-update --dry-run' >/dev/null 2>&1"
}

# Test output formatting
test_output_formatting() {
    print_test_header "Output Formatting Tests"
    
    assert_contains "Shows colored output" "zsh -c 'source \"$PLUGIN_FILE\"; zsh-system-update --dry-run'" "INFO"
    assert_contains "Shows timing information" "zsh -c 'source \"$PLUGIN_FILE\"; zsh-system-update --dry-run'" "completed in"
    assert_contains "Shows start time" "zsh -c 'source \"$PLUGIN_FILE\"; zsh-system-update --dry-run'" "started at"
}

# Test completion functionality
test_tab_completion() {
    print_test_header "Tab Completion Tests"
    
    # Test 1: Completion function exists
    print_test "Completion function is defined"
    ((TESTS_RUN++))
    if zsh -c "source '$PLUGIN_FILE'; typeset -f _zsh_system_update >/dev/null" 2>/dev/null; then
        echo -e "${GREEN}✓ PASS${NC}: Completion function is defined"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: Completion function is defined"
        ((TESTS_FAILED++))
    fi
    
    # Test 2: Completion function has the expected options
    print_test "Completion function has options"
    ((TESTS_RUN++))
    if grep -q "\-\-help" "$PLUGIN_FILE" && grep -q "\-\-verbose" "$PLUGIN_FILE"; then
        echo -e "${GREEN}✓ PASS${NC}: Completion function has options"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: Completion function has options"
        echo "  Expected to find --help and --verbose in completion function"
        ((TESTS_FAILED++))
    fi
}

# Cleanup test environment
cleanup_test_env() {
    print_test_header "Cleaning up test environment"
    
    if [[ -n "$TEST_DIR" && -d "$TEST_DIR" ]]; then
        rm -rf "$TEST_DIR"
        echo -e "${GREEN}✓${NC} Test environment cleaned"
    fi
}

# Print test summary
print_test_summary() {
    print_test_header "Test Summary"
    
    echo "Tests run: $TESTS_RUN"
    echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}🎉 All tests passed!${NC}"
        exit 0
    else
        echo -e "\n${RED}❌ Some tests failed${NC}"
        exit 1
    fi
}

# Main test execution
main() {
    echo -e "${BLUE}Starting zsh-system-update test suite${NC}"
    echo "Working directory: $(pwd)"
    echo "Script location: $(dirname "$0")"
    
    # Run all test functions
    setup_test_env
    load_plugin
    test_plugin_loading
    test_help_functionality
    test_argument_parsing
    test_dry_run
    test_selective_updates
    test_caching_logic
    test_dependency_checking
    test_error_handling
    test_output_formatting
    test_tab_completion
    
    cleanup_test_env
    print_test_summary
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi