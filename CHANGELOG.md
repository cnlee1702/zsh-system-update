# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.6] - 2025-10-09

### Fixed
- **Conda Environment Handling** - Fixed glob pattern error when conda environments directory is empty
  - Resolved "no matches found" error in pip-manager.zsh when `/home/user/miniforge3/envs/*` contains no environments
  - Added `null_glob` option to handle empty directory patterns gracefully
  - Ensures pip updates continue working even with fresh conda installations

## [0.3.5] - 2025-08-13

### Fixed
- **Documentation Accuracy** - Aligned cache threshold documentation with code implementation
  - Updated README.md cache descriptions to match actual defaults (Conda: 1 week, Pip: 1 week)
  - Fixed configuration examples to reflect correct threshold values
  - Corrected performance impact claims to be realistic and evidence-based
- **Code Comment Cleanup** - Removed stale comments and improved documentation consistency  
  - Removed outdated "Fixed:" comment from output utilities
  - Standardized code comment formatting for better maintainability
- **Feature Documentation** - Eliminated redundant feature descriptions in README.md
  - Consolidated duplicate caching feature descriptions into single clear statement
  - Improved feature list clarity and reduced confusion

### Changed
- **Performance Claims** - Updated README.md performance section for accuracy
  - Replaced overstated "75-85% time saved" claims with realistic caching behavior descriptions
  - Focused documentation on actual benefits: comprehensive coverage, safety, and convenience
  - Emphasized plugin's real value proposition rather than unsubstantiated speed claims

### Technical Details
- Documentation now accurately reflects cache thresholds: APT (1 hour), Conda (1 week), Flatpak (2 hours), Pip (1 week)
- All user-facing documentation aligned with implementation for consistent user experience
- Maintains full backward compatibility with all existing functionality

## [0.3.4] - 2025-08-12

### Added
- **Cache Management Commands** - Direct cache control without running updates
  - `--clear-cache <manager(s)>` - Clear cache for specific manager(s) (apt, conda, pip, flatpak)
  - `--clear-all-cache` - Clear all package manager caches at once
  - `--list-cache` - List all cache entries with timestamps
  - Support for multiple managers: `--clear-cache apt conda pip`
  - Input validation for manager names with helpful error messages
  - Full zsh tab completion support for new cache options

### Enhanced
- **Cache Clearing Functions** - New core cache utilities in `lib/utils/cache.zsh`
  - `zsu_cache_clear()` - Clear cache for specific manager with optional environment ID
  - `zsu_cache_clear_all()` - Clear all cache entries with count reporting
  - Comprehensive error handling and user-friendly status messages
  - Support for environment-specific cache clearing (e.g., conda environments)

### Testing
- **Cache Management Test Suite** - New comprehensive test coverage
  - 19 new tests in `tests/unit/test-cache-utils.sh`
  - Integration tests for cache clearing with existing functionality
  - Error handling validation for invalid manager names
  - Multi-manager cache clearing validation
  - Total test coverage now: 51 individual tests across 5 test suites

## [0.3.3] - 2025-08-12

### Added
- **Unified Cache System** - Centralized caching with configurable thresholds
  - Shared cache utilities in `lib/utils/cache.zsh` for all package managers
  - Configurable cache thresholds via environment variables:
    - `ZSU_CACHE_THRESHOLD_APT` (default: 1 hour)
    - `ZSU_CACHE_THRESHOLD_CONDA` (default: 168 hours/1 week)
    - `ZSU_CACHE_THRESHOLD_FLATPAK` (default: 24 hours)
    - `ZSU_CACHE_THRESHOLD_PIP` (default: 24 hours)
  - Environment-specific caching for conda and pip virtual environments
  - Force update flags override cache behavior for immediate updates

- **Comprehensive Test Suite Enhancement** - Expanded testing infrastructure
  - Enhanced main test runner (`./test`) with new options:
    - `--unit-only` - Run 32 unit tests across 4 managers (5s execution)
    - `--integration-only` - Run 38 integration tests (13s execution) 
    - `--lint-only` - Comprehensive linting of all shell files
  - **Expanded Linting Scope** - Now lints 14 files vs previous 2 files
    - All library files in `lib/` directory (6 files)
    - All test files in `tests/` directory (7 files)  
    - Smart error vs warning categorization (warnings don't fail build)
  - Enhanced visual reporting with execution timing and detailed summaries
  - Comprehensive test phase tracking with accurate progress indicators

### Fixed
- **Code Quality Improvements** - Resolved critical shellcheck errors
  - Fixed SC2168 errors: Invalid 'local' declarations at top-level in library files
  - Implemented clean namespace management using self-cleaning functions
  - Fixed zsh-specific syntax compatibility issues for cross-shell support
  - Corrected function definition syntax in main plugin file

- **Test Runner Display Issues** - Enhanced visual feedback
  - Fixed color code rendering (ANSI codes now display as actual colors)
  - Corrected test phase counting logic (perfect 1:1 started/completed mapping)
  - Improved progress tracking accuracy and reliability

### Technical Details
- **Cache System Architecture**: Unified interface with manager-specific thresholds
- **Code Quality**: 0 critical errors, 13 minor warnings across 14 linted files
- **Test Coverage**: 70 total tests (38 integration + 32 unit tests) with 100% pass rate
- **Enhanced Workflow**: Multiple test execution modes for different development needs
- **Visual Excellence**: Professional terminal output with proper color rendering

## [0.3.2] - 2025-08-04

### Added
- **Comprehensive Test Suite Enhancement** - Dramatically expanded test coverage
  - **Manager Module Unit Tests** - 32 new unit tests covering all package managers
    - APT Manager: 7 tests (availability, cache logic, skip functionality, dry run)
    - Conda Manager: 10 tests (detection, cache thresholds, environment handling)
    - Pip Manager: 7 tests (functionality, environments, cache management)
    - Flatpak Manager: 8 tests (availability, cache logic, force updates)
  - **Professional Test Runner** - New `tests/run-unit-tests.sh` with consolidated reporting
  - **Shared Test Utilities** - Reusable testing framework with bash/zsh compatibility
  - **Enhanced Integration Tests** - Expanded existing test suite to 38 total tests

### Fixed
- **Test Suite Compatibility** - Resolved zsh compatibility warnings in test execution
  - Fixed "colors: command not found" warnings with proper compatibility layer
  - Enhanced test utilities with bash/zsh mock functions
  - Warning-free test execution across all environments
- **CI Configuration** - Streamlined GitHub Actions workflow triggers
  - Removed `develop` branch from CI triggers, now only triggers on `master` branch
  - Added comprehensive test suite execution to CI pipeline
  - Removed hardcoded test counts and success messages from CI output

### Technical Details
- Comprehensive test coverage: 70 total tests (38 integration + 32 unit tests)
- All functionality preserved and tested (70/70 tests pass, 100% success rate)
- Maintains full backward compatibility with all command-line options
- Warning-free test execution with proper zsh/bash compatibility layer
- Enhanced CI/CD pipeline with comprehensive test validation

## [0.3.1] - 2025-08-04

### Fixed
- **Hook Guard Protection** - Added execution guard to prevent undesired function execution
  - Prevents recursive or unexpected execution when other commands are run
  - Uses `ZSU_RUNNING` environment variable to track execution state
  - Includes proper cleanup with trap handlers for EXIT, INT, and TERM signals
  - Resolves issue where plugin would unexpectedly run during `conda activate` and similar commands

### Technical Details
- Hook guard implementation at function entry point (`zsh-system-update.plugin.zsh:34-44`)
- All existing functionality preserved and tested (33/33 tests pass)
- Maintains full backward compatibility with all command-line options

## [0.3.0] - 2025-07-21

### Changed
- **Modular Architecture Refactor** - Split functionality into separate manager modules
  - Moved APT management to `lib/managers/apt-manager.zsh`
  - Moved Conda management to `lib/managers/conda-manager.zsh`
  - Moved pip management to `lib/managers/pip-manager.zsh`
  - Moved Flatpak management to `lib/managers/flatpak-manager.zsh`
  - Moved output utilities to `lib/utils/output.zsh`
- **Enhanced Test Suite** - Improved assertions and dynamic conda detection testing
- **Code Quality** - Cleaned up unused test arrays and improved error handling

### Technical Details
- Improved maintainability with clear separation of concerns
- Each package manager now has its own dedicated module
- Enhanced dependency management with proper module imports
- Better error handling and graceful fallbacks for missing dependencies

## [0.2.0] - 2025-06-25

### Added
- **Flatpak/Flathub support** - Complete integration for Flatpak application updates
  - Smart caching system with 2-hour threshold (same as Conda)
  - Repository updates with `flatpak update --appstream`
  - Application updates with `flatpak update --assumeyes`
  - Automatic cleanup of unused runtimes with `flatpak uninstall --unused`
  - Graceful handling when Flatpak is not installed
- **New command-line options for Flatpak**
  - `--flatpak-only` - Update only Flatpak applications
  - `--skip-flatpak` - Skip Flatpak updates in combined runs
  - `--force-flatpak` - Force Flatpak update regardless of cache timing
- **Enhanced help system**
  - Reorganized help output with clear package manager sections
  - Added caching information for all supported package managers
  - Updated examples to demonstrate Flatpak usage
- **Expanded tab completion**
  - All new Flatpak options included in zsh completion
  - Improved completion descriptions and organization
- **Updated test suite**
  - Added comprehensive Flatpak functionality tests
  - Enhanced selective update testing for all 4 package managers
  - Updated tab completion validation

### Changed
- **Improved help organization** - Grouped options by category (Package Managers, Cache Control)
- **Enhanced --force flag** - Now includes Flatpak when forcing all updates
- **Updated version display** - Shows current version with --version flag
- **Refined command-line parsing** - Better error messages for unknown options

### Technical Details
- Now supports 4 major package managers: APT, Conda, pip, and Flatpak
- Consistent caching patterns across all package managers
- Maintains backward compatibility with all existing options
- Flatpak integration follows same patterns as existing package managers

## [0.1.0] - 2025-05-29

### Added
- Initial release of zsh-system-update plugin
- Smart caching system for APT and Conda updates
- Support for APT system package management
  - Package list updates with 1-hour caching
  - Automatic package upgrades with configuration handling
  - Cleanup operations (autoremove, autoclean)
- Conda environment management
  - Combined conda and mamba updates with 2-hour caching
  - Automatic cache cleaning after updates
  - Support for both miniconda3 and anaconda3 installations
- Pip package management across all environments
  - Base environment pip updates
  - Automatic detection and update of pip in all conda environments
  - Global pip cache purging
- Comprehensive command-line interface
  - Verbose, quiet, and dry-run modes
  - Selective update options (apt-only, conda-only, skip options)
  - Force update flags to bypass caching
  - Built-in help system
- Performance optimizations
  - 75-85% time savings on repeated runs within cache windows
  - Intelligent timestamp-based update decisions
  - Absolute path usage to prevent recursive function calls
- User experience enhancements
  - Color-coded output messages
  - Progress indicators and timing information
  - Dependency checking with helpful error messages
  - Tab completion support for all command options
- Error handling and safety features
  - Graceful handling of missing dependencies
  - Automatic configuration prompt handling for APT
  - Safe fallbacks when cache detection fails
  - Protection against infinite recursion

### Technical Details
- Compatible with zsh and oh-my-zsh plugin system
- Uses local variables to prevent namespace pollution
- Implements proper argument parsing with validation
- Follows oh-my-zsh plugin conventions and structure

[Unreleased]: https://github.com/cnlee1702/zsh-system-update/compare/v0.3.2...HEAD
[0.3.2]: https://github.com/cnlee1702/zsh-system-update/compare/v0.3.1...v0.3.2
[0.3.1]: https://github.com/cnlee1702/zsh-system-update/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/cnlee1702/zsh-system-update/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/cnlee1702/zsh-system-update/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/cnlee1702/zsh-system-update/releases/tag/v0.1.0