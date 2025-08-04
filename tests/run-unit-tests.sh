#!/bin/bash

# Unit Test Runner for zsh-system-update
# Runs all unit tests and provides consolidated reporting

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Global test counters
TOTAL_TESTS_RUN=0
TOTAL_TESTS_PASSED=0
TOTAL_TESTS_FAILED=0
SUITE_COUNT=0
PASSED_SUITES=0
FAILED_SUITES=0

# Function to run a single test suite
run_test_suite() {
    local test_file="$1"
    local suite_name="$2"
    
    echo -e "\n${BLUE}🧪 Running $suite_name Unit Tests${NC}"
    echo "================================================="
    
    if [[ ! -f "$test_file" ]]; then
        echo -e "${RED}✗ Test file not found: $test_file${NC}"
        return 1
    fi
    
    if [[ ! -x "$test_file" ]]; then
        echo -e "${RED}✗ Test file not executable: $test_file${NC}"
        return 1
    fi
    
    # Run the test suite and capture results
    local output
    local exit_code
    
    output=$("$test_file" 2>&1)
    exit_code=$?
    
    # Strip ANSI color codes for better parsing
    local clean_output=$(echo "$output" | sed 's/\x1b\[[0-9;]*m//g')
    
    # Extract test statistics from cleaned output
    local tests_run=$(echo "$clean_output" | grep "Tests run:" | tail -1 | sed 's/.*Tests run: \([0-9]*\).*/\1/')
    local tests_passed=$(echo "$clean_output" | grep "Passed:" | tail -1 | sed 's/.*Passed: \([0-9]*\).*/\1/')
    local tests_failed=$(echo "$clean_output" | grep "Failed:" | tail -1 | sed 's/.*Failed: \([0-9]*\).*/\1/')
    
    # Default to 0 if extraction failed
    tests_run=${tests_run:-0}
    tests_passed=${tests_passed:-0}
    tests_failed=${tests_failed:-0}
    
    # If we still have 0 for all values, try alternative extraction
    if [[ $tests_run -eq 0 && $tests_passed -eq 0 && $tests_failed -eq 0 ]]; then
        # Count PASS/FAIL lines as backup method
        tests_passed=$(echo "$clean_output" | grep -c "✓ PASS\|All.*tests passed")
        tests_failed=$(echo "$clean_output" | grep -c "✗ FAIL")
        tests_run=$((tests_passed + tests_failed))
    fi
    
    # Update global counters
    TOTAL_TESTS_RUN=$((TOTAL_TESTS_RUN + tests_run))
    TOTAL_TESTS_PASSED=$((TOTAL_TESTS_PASSED + tests_passed))
    TOTAL_TESTS_FAILED=$((TOTAL_TESTS_FAILED + tests_failed))
    ((SUITE_COUNT++))
    
    # Print results
    if [[ $exit_code -eq 0 ]]; then
        echo -e "${GREEN}✓ $suite_name: $tests_passed/$tests_run tests passed${NC}"
        ((PASSED_SUITES++))
    else
        echo -e "${RED}✗ $suite_name: $tests_failed/$tests_run tests failed${NC}"
        ((FAILED_SUITES++))
        
        # Show detailed output for failed suites
        echo -e "\n${YELLOW}Detailed output for $suite_name:${NC}"
        echo "$output" | grep -E "(FAIL|ERROR|✗)" || echo "$output"
    fi
    
    return $exit_code
}

# Main execution
main() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                 ZSH-SYSTEM-UPDATE UNIT TESTS              ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    
    local start_time=$(date +%s)
    local overall_success=true
    
    # Define test suites
    local test_suites=(
        "$SCRIPT_DIR/unit/test-apt-manager.sh:APT Manager"
        "$SCRIPT_DIR/unit/test-conda-manager.sh:Conda Manager"
        "$SCRIPT_DIR/unit/test-pip-manager.sh:Pip Manager"
        "$SCRIPT_DIR/unit/test-flatpak-manager.sh:Flatpak Manager"
    )
    
    # Run each test suite
    for suite_def in "${test_suites[@]}"; do
        local test_file="${suite_def%:*}"
        local suite_name="${suite_def#*:}"
        
        if ! run_test_suite "$test_file" "$suite_name"; then
            overall_success=false
        fi
    done
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Print final summary
    echo -e "\n${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                      FINAL SUMMARY                         ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    
    echo "Test Execution Time: ${duration}s"
    echo "Test Suites Run: $SUITE_COUNT"
    echo -e "Suites Passed: ${GREEN}$PASSED_SUITES${NC}"
    echo -e "Suites Failed: ${RED}$FAILED_SUITES${NC}"
    echo ""
    echo "Total Individual Tests: $TOTAL_TESTS_RUN"
    echo -e "Total Tests Passed: ${GREEN}$TOTAL_TESTS_PASSED${NC}"
    echo -e "Total Tests Failed: ${RED}$TOTAL_TESTS_FAILED${NC}"
    
    # Calculate coverage estimate
    local coverage_percent=0
    if [[ $TOTAL_TESTS_RUN -gt 0 ]]; then
        coverage_percent=$((TOTAL_TESTS_PASSED * 100 / TOTAL_TESTS_RUN))
    fi
    echo -e "Test Success Rate: ${GREEN}${coverage_percent}%${NC}"
    
    # Final result
    if $overall_success && [[ $TOTAL_TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}🎉 ALL UNIT TESTS PASSED!${NC}"
        echo -e "${GREEN}The modular functionality is well tested and reliable.${NC}"
        exit 0
    else
        echo -e "\n${RED}❌ SOME UNIT TESTS FAILED${NC}"
        echo -e "${RED}Please review the failed tests and fix the issues.${NC}"
        exit 1
    fi
}

# Show help
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Run all unit tests for zsh-system-update plugin manager modules."
    echo ""
    echo "OPTIONS:"
    echo "  -h, --help     Show this help message"
    echo "  -v, --verbose  Show detailed output for all tests"
    echo ""
    echo "Test Suites:"
    echo "  • APT Manager Unit Tests"
    echo "  • Conda Manager Unit Tests"
    echo "  • Pip Manager Unit Tests"
    echo "  • Flatpak Manager Unit Tests"
}

# Parse command line arguments
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    -v|--verbose)
        export VERBOSE_TESTS=true
        ;;
    "")
        # No arguments, proceed with tests
        ;;
    *)
        echo "Unknown option: $1"
        show_help
        exit 1
        ;;
esac

# Run main function
main "$@"