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
    
    print_unit_test_summary "Cache Utilities"
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi