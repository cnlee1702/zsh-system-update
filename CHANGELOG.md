# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/yourusername/zsh-system-update/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/yourusername/zsh-system-update/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/yourusername/zsh-system-update/releases/tag/v0.1.0