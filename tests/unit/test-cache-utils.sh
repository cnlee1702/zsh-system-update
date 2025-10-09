#!/bin/bash

# Unit tests for cache utility functions
# Tests the lib/utils/cache.zsh module

# Get script directory and load test utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../test-utils.sh"

# Test cache clearing functionality
test_cache_clear_functions() {
    print_test_header "Cache Clear Functions Tests"
    
    setup_unit_test_env
    load_test_plugin
    
    # Load cache utilities module
    if ! zsu_import "lib/utils/cache.zsh"; then
        echo -e "${RED}✗${NC} Failed to load cache utilities module"
        return 1
    fi
    
    # Set up test environment with custom cache directory
    export ZSU_CACHE_DIR="$UNIT_TEST_DIR/cache"
    export ZSU_CURRENT_TIME="$(date +%s)"
    
    # Initialize cache directory
    zsu_cache_init
    
    # Test 1: Clear non-existent cache (specific manager)
    assert_contains "Clear non-existent cache shows appropriate message" \
        "zsu_cache_clear apt" \
        "No cache found for apt"
    
    # Test 2: Create some cache files and test clearing specific manager
    touch "$ZSU_CACHE_DIR/apt"
    touch "$ZSU_CACHE_DIR/conda"
    touch "$ZSU_CACHE_DIR/pip"
    
    assert_contains "Clear specific manager cache (apt)" \
        "zsu_cache_clear apt" \
        "Cleared cache for apt"
    
    assert_success "Apt cache file should be gone after clearing" \
        "[[ ! -f '$ZSU_CACHE_DIR/apt' ]]"
    
    assert_success "Other cache files should still exist" \
        "[[ -f '$ZSU_CACHE_DIR/conda' && -f '$ZSU_CACHE_DIR/pip' ]]"
    
    # Test 3: Clear cache with environment ID
    touch "$ZSU_CACHE_DIR/conda_myenv"
    
    assert_contains "Clear cache with environment ID" \
        "zsu_cache_clear conda myenv" \
        "Cleared cache for conda (environment: myenv)"
    
    assert_success "Environment-specific cache file should be gone" \
        "[[ ! -f '$ZSU_CACHE_DIR/conda_myenv' ]]"
    
    # Test 4: Clear all caches
    touch "$ZSU_CACHE_DIR/apt"
    touch "$ZSU_CACHE_DIR/flatpak"
    
    assert_contains "Clear all caches" \
        "zsu_cache_clear_all" \
        "Cleared 4 cache entries"
    
    assert_success "All cache files should be gone" \
        "[[ ! -f '$ZSU_CACHE_DIR/apt' && ! -f '$ZSU_CACHE_DIR/conda' && ! -f '$ZSU_CACHE_DIR/pip' && ! -f '$ZSU_CACHE_DIR/flatpak' ]]"
    
    # Test 5: Clear all when no caches exist
    assert_contains "Clear all when no caches exist" \
        "zsu_cache_clear_all" \
        "No cache entries to clear"
    
    # Test 6: Error handling for missing manager name
    assert_failure "Clear cache without manager name should fail" \
        "zsu_cache_clear"
    
    assert_contains "Clear cache without manager name shows error" \
        "zsu_cache_clear 2>&1" \
        "ERROR: Manager name is required"
    
    cleanup_unit_test_env
}

# Test cache clearing integration with existing functions
test_cache_clear_integration() {
    print_test_header "Cache Clear Integration Tests"
    
    setup_unit_test_env
    load_test_plugin
    
    # Load cache utilities module
    if ! zsu_import "lib/utils/cache.zsh"; then
        echo -e "${RED}✗${NC} Failed to load cache utilities module"
        return 1
    fi
    
    # Set up test environment
    export ZSU_CACHE_DIR="$UNIT_TEST_DIR/cache"
    export ZSU_CURRENT_TIME="$(date +%s)"
    
    # Initialize and create some cache files with different timestamps
    zsu_cache_init
    create_mock_cache "$ZSU_CACHE_DIR/apt" 0.5  # 30 minutes ago
    create_mock_cache "$ZSU_CACHE_DIR/conda" 2   # 2 hours ago
    create_mock_cache "$ZSU_CACHE_DIR/pip_env1" 1 # 1 hour ago
    
    # Test 1: List caches before clearing
    assert_contains "List caches shows all entries" \
        "zsu_cache_list" \
        "Cache entries:"
    
    assert_contains "List caches shows apt entry" \
        "zsu_cache_list" \
        "apt:"
    
    # Test 2: Clear specific cache and verify list updates
    zsu_cache_clear apt >/dev/null
    
    assert_not_contains "List caches should not show cleared apt entry" \
        "zsu_cache_list" \
        "apt:"
    
    assert_contains "List caches should still show conda entry" \
        "zsu_cache_list" \
        "conda:"
    
    # Test 3: Clear all and verify list is empty
    zsu_cache_clear_all >/dev/null
    
    assert_contains "List caches after clear all should show empty" \
        "zsu_cache_list" \
        "No cache entries found"
    
    # Test 4: Integration with cache_needs_update after clearing
    # After clearing, cache should indicate update is needed
    assert_success "Cache needs update after clearing" \
        "zsu_cache_needs_update apt"
    
    # Touch cache and verify update is not needed
    zsu_cache_touch apt
    assert_failure "Cache should not need update after touching" \
        "zsu_cache_needs_update apt"
    
    # Clear specific cache and verify update is needed again
    zsu_cache_clear apt >/dev/null
    assert_success "Cache needs update after clearing specific cache" \
        "zsu_cache_needs_update apt"
    
    cleanup_unit_test_env
}

# Test preference management functions
test_preference_functions() {
    print_test_header "Preference Management Tests"
    
    setup_unit_test_env
    load_test_plugin
    
    # Load cache utilities module
    if ! zsu_import "lib/utils/cache.zsh"; then
        echo -e "${RED}✗${NC} Failed to load cache utilities module"
        return 1
    fi
    
    # Set up test environment with custom cache directory
    export ZSU_CACHE_DIR="$UNIT_TEST_DIR/cache"
    
    # Initialize cache directory
    zsu_cache_init
    
    # Test 1: Preference functions exist
    assert_success "Preference set function exists" "declare -f zsu_preference_set >/dev/null"
    assert_success "Preference get function exists" "declare -f zsu_preference_get >/dev/null"
    assert_success "Preference exists function exists" "declare -f zsu_preference_exists >/dev/null"
    
    # Test 2: Setting and getting preferences
    run_test "Setting and getting basic preference"
    zsu_preference_set "test_key" "test_value" >/dev/null 2>&1
    local retrieved_value=$(zsu_preference_get "test_key" "default")
    if [[ "$retrieved_value" == "test_value" ]]; then
        echo -e "${GREEN}✓ PASS${NC}: Setting and getting basic preference"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: Expected 'test_value', got '$retrieved_value'"
        ((TESTS_FAILED++))
    fi
    
    # Test 3: Default value handling
    run_test "Default value handling for non-existent preference"
    local default_value=$(zsu_preference_get "nonexistent_key" "default_val")
    if [[ "$default_value" == "default_val" ]]; then
        echo -e "${GREEN}✓ PASS${NC}: Default value handling works"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: Expected 'default_val', got '$default_value'"
        ((TESTS_FAILED++))
    fi
    
    # Test 4: Preference exists function
    run_test "Preference exists function"
    if zsu_preference_exists "test_key"; then
        echo -e "${GREEN}✓ PASS${NC}: Preference exists function returns true for existing key"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: Preference exists function returned false for existing key"
        ((TESTS_FAILED++))
    fi
    
    if ! zsu_preference_exists "nonexistent_key"; then
        echo -e "${GREEN}✓ PASS${NC}: Preference exists function returns false for non-existent key"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: Preference exists function returned true for non-existent key"
        ((TESTS_FAILED++))
    fi
    
    # Test 5: Updating existing preference
    run_test "Updating existing preference"
    zsu_preference_set "test_key" "updated_value" >/dev/null 2>&1
    local updated_value=$(zsu_preference_get "test_key" "default")
    if [[ "$updated_value" == "updated_value" ]]; then
        echo -e "${GREEN}✓ PASS${NC}: Updating existing preference works"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: Expected 'updated_value', got '$updated_value'"
        ((TESTS_FAILED++))
    fi
    
    # Test 6: Multiple preferences
    run_test "Multiple preferences handling"
    zsu_preference_set "key1" "value1" >/dev/null 2>&1
    zsu_preference_set "key2" "value2" >/dev/null 2>&1
    zsu_preference_set "key3" "value3" >/dev/null 2>&1
    
    local val1=$(zsu_preference_get "key1" "default")
    local val2=$(zsu_preference_get "key2" "default")
    local val3=$(zsu_preference_get "key3" "default")
    
    if [[ "$val1" == "value1" && "$val2" == "value2" && "$val3" == "value3" ]]; then
        echo -e "${GREEN}✓ PASS${NC}: Multiple preferences handling works"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: Multiple preferences failed - got '$val1', '$val2', '$val3'"
        ((TESTS_FAILED++))
    fi
    
    # Test 7: Preference file format
    run_test "Preference file format is correct"
    local pref_file="$ZSU_CACHE_DIR/preferences"
    if [[ -f "$pref_file" ]]; then
        local line_count=$(grep -c "=" "$pref_file" 2>/dev/null || echo 0)
        if [[ $line_count -ge 3 ]]; then
            echo -e "${GREEN}✓ PASS${NC}: Preference file format is correct"
            ((TESTS_PASSED++))
        else
            echo -e "${RED}✗ FAIL${NC}: Preference file format incorrect - expected at least 3 lines with '='"
            ((TESTS_FAILED++))
        fi
    else
        echo -e "${RED}✗ FAIL${NC}: Preference file was not created"
        ((TESTS_FAILED++))
    fi
    
    # Test 8: Preference persistence across function calls
    run_test "Preference persistence across function calls"
    # Clear variables to simulate new shell session
    unset ZSU_CACHE_DIR
    export ZSU_CACHE_DIR="$UNIT_TEST_DIR/cache"
    
    local persistent_value=$(zsu_preference_get "key1" "default")
    if [[ "$persistent_value" == "value1" ]]; then
        echo -e "${GREEN}✓ PASS${NC}: Preference persistence works"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: Expected 'value1', got '$persistent_value'"
        ((TESTS_FAILED++))
    fi
    
    cleanup_unit_test_env
}

# Run all tests
main() {
    echo -e "${BLUE}Starting Cache Utilities Tests${NC}\n"
    
    # Run test functions
    if ! test_cache_clear_functions; then
        echo -e "${RED}✗ Cache clear functions tests failed${NC}"
        exit 1
    fi
    
    if ! test_cache_clear_integration; then
        echo -e "${RED}✗ Cache clear integration tests failed${NC}"
        exit 1
    fi
    
    if ! test_preference_functions; then
        echo -e "${RED}✗ Preference functions tests failed${NC}"
        exit 1
    fi
    
    print_unit_test_summary "Cache Utilities"
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi