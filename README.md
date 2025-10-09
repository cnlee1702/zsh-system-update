# zsh-system-update

A smart, efficient system update plugin for oh-my-zsh that handles APT packages, Conda environments, pip installations, and Flatpak applications with intelligent caching to minimize update times.

## Features

- 🚀 **Smart Caching**: Skips unnecessary updates based on configurable time thresholds
- 📦 **Multi-Package Manager Support**: Updates APT, Conda, pip, and Flatpak applications
- 🐍 **Multi-Environment Support**: Updates pip across all conda environments automatically  
- 🎛️ **Flexible Options**: Granular control over what gets updated
- 🎨 **Beautiful Output**: Color-coded status messages and progress indicators
- 🛡️ **Safe Defaults**: Handles configuration prompts and errors gracefully
- 🔧 **Modular Architecture**: Clean separation of package managers for easy maintenance

## Quick Start

### Installation

1. **Clone to oh-my-zsh custom plugins directory:**
   ```bash
   git clone https://github.com/yourusername/zsh-system-update.git ~/.oh-my-zsh/custom/plugins/zsh-system-update
   ```

2. **Add to your plugins list in `~/.zshrc`:**
   ```bash
   plugins=(... zsh-system-update)
   ```

3. **Reload your shell:**
   ```bash
   source ~/.zshrc
   ```

### Basic Usage

```bash
# Full system update
zsh-system-update

# Silent mode
zsh-system-update --quiet

# Verbose mode with detailed output
zsh-system-update --verbose

# Preview what would run
zsh-system-update --dry-run
```

## Smart Caching

The plugin uses intelligent time-based caching to avoid unnecessary work:

- **APT updates**: Cached for 1 hour (repositories don't change frequently)
- **Conda updates**: Cached for 1 week (larger operations, less frequent updates)
- **Flatpak updates**: Cached for 2 hours (similar to APT, moderate frequency updates)
- **Pip updates**: Cached for 1 week (checked per environment, less frequent updates)

### Caching Benefits

The plugin provides intelligent caching to avoid redundant operations:

| Scenario | Behavior | Benefit |
|----------|----------|---------|
| First run | All managers execute normally | Full system coverage |
| Within cache window | Cached managers skip operations | Reduced redundant work |
| Force updates | All managers execute regardless of cache | Override when needed |

**Primary advantages:** Comprehensive system coverage, safe configuration handling, unified interface for multiple package managers, and automatic multi-environment support rather than raw performance gains.

### Cache Management

You can manage caches directly without running updates:

```bash
# View cache status for all managers
zsh-system-update --list-cache

# Clear specific manager caches to force fresh updates
zsh-system-update --clear-cache apt conda

# Clear all caches at once
zsh-system-update --clear-all-cache
```

## Command Options

### Basic Options
- `-h, --help` - Show help message
- `-q, --quiet` - Suppress most output  
- `-v, --verbose` - Show detailed output including commands
- `--dry-run` - Preview what would be executed without running

### Selective Updates
- `--apt-only` - Only run APT system package updates
- `--conda-only` - Only run Conda and pip environment updates
- `--flatpak-only` - Only run Flatpak application updates
- `--skip-apt` - Skip APT system updates
- `--skip-conda` - Skip Conda updates  
- `--skip-pip` - Skip pip updates
- `--skip-flatpak` - Skip Flatpak updates

### Cache Control
- `--force-apt-update` - Force APT update even if recently updated
- `--force-conda-update` - Force Conda update even if recently updated
- `--force-flatpak-update` - Force Flatpak update even if recently updated
- `--clear-cache <manager(s)>` - Clear cache for specific manager(s) (apt, conda, pip, flatpak)
- `--clear-all-cache` - Clear all package manager caches
- `--list-cache` - List all cache entries with timestamps

## Usage Examples

```bash
# Daily maintenance (respects all caching)
zsh-system-update

# Weekly deep clean (force everything)
zsh-system-update --force-apt-update --force-conda-update

# System packages only
zsh-system-update --apt-only

# Python environments only  
zsh-system-update --conda-only

# Flatpak applications only
zsh-system-update --flatpak-only

# Check what needs updating
zsh-system-update --dry-run --verbose

# Silent background update
zsh-system-update --quiet

# Cache management examples
zsh-system-update --list-cache                    # Show cache status
zsh-system-update --clear-cache apt               # Clear APT cache only  
zsh-system-update --clear-cache apt conda         # Clear APT and Conda caches
zsh-system-update --clear-all-cache               # Clear all caches
```

## What Gets Updated

### System Packages (APT)
- Updates package lists from repositories
- Upgrades installed packages with safety configurations
- Removes unnecessary packages (`autoremove --purge`)
- Cleans package cache (`autoclean`)

### Conda Environment
- Updates conda itself and mamba
- Cleans conda package cache
- Uses absolute paths to avoid conflicts

### Python Packages (Pip)
- Updates pip in base environment
- Updates pip in all conda environments
- Cleans pip cache after all updates

### Flatpak Applications
- Updates application repositories (`appstream`)
- Updates all installed Flatpak applications
- Removes unused runtimes and dependencies
- Cleans Flatpak cache

## Requirements

### System Requirements
- Linux (tested on Linux Mint/Ubuntu)
- zsh shell with oh-my-zsh
- sudo access for system package updates

### Dependencies
The plugin checks for required commands automatically:
- `apt-get` (system packages) - optional, skipped if not available
- `conda` (conda environment management) - optional, auto-detected from multiple locations
- `python` (pip updates) - required for pip functionality
- `flatpak` (Flatpak applications) - optional, skipped if not available
- Standard Unix utilities (`basename`, `wc`, `grep`, `stat`, `find`)

## Configuration

### Cache Configuration
Configure cache thresholds using environment variables in your `~/.zshrc`:

```bash
# Cache thresholds (in seconds)
export ZSU_CACHE_THRESHOLD_APT=3600      # APT: 1 hour (default)
export ZSU_CACHE_THRESHOLD_CONDA=604800  # Conda: 1 week (default) 
export ZSU_CACHE_THRESHOLD_FLATPAK=7200  # Flatpak: 2 hours (default)
export ZSU_CACHE_THRESHOLD_PIP=604800    # Pip: 1 week (default)

# Example: More frequent APT updates
export ZSU_CACHE_THRESHOLD_APT=1800      # Check every 30 minutes
```

The unified cache system provides consistent behavior across all package managers with easily configurable thresholds.

### Conda Installation Detection
The plugin automatically detects conda installations from multiple sources:
- Commands in PATH (`conda` command, `CONDA_EXE` environment variable)
- Common installation locations (`~/miniconda3/`, `~/anaconda3/`, `~/mambaforge/`, etc.)
- Environment variables (`CONDA_PREFIX`, `CONDA_EXE`)
- Package manager installations (`/opt/`, `/usr/local/`)

## Troubleshooting

### Common Issues

**Plugin not loading:**
```bash
# Check if plugin is in correct location
ls ~/.oh-my-zsh/custom/plugins/zsh-system-update/

# Verify plugins list in ~/.zshrc
grep "plugins=" ~/.zshrc
```

**Permission errors:**
```bash
# Ensure sudo access for APT operations
sudo -v
```

**Conda not found:**
```bash
# Check conda installation and detection
which conda
conda --version

# Test conda detection with verbose output
zsh-system-update --conda-only --verbose --dry-run
```

**Flatpak issues:**
```bash
# Check Flatpak installation
which flatpak
flatpak --version

# List installed Flatpak applications
flatpak list
```

### Debug Mode

Enable verbose output to see exactly what's happening:
```bash
zsh-system-update --verbose --dry-run
```

## Contributing

Contributions are welcome! Please feel free to submit issues, feature requests, or pull requests.

### Development Setup

1. Fork the repository
2. Make changes to the main plugin file or manager modules in `lib/managers/`
3. **Run comprehensive tests:**
   ```bash
   # Run all tests (integration + unit tests)
   ./tests/test-zsh-system-update.sh     # 38 integration tests
   ./tests/run-unit-tests.sh             # 32 unit tests
   
   # Run specific manager unit tests
   ./tests/unit/test-apt-manager.sh       # APT manager tests
   ./tests/unit/test-conda-manager.sh     # Conda manager tests
   ./tests/unit/test-pip-manager.sh       # Pip manager tests
   ./tests/unit/test-flatpak-manager.sh   # Flatpak manager tests
   ```
4. Test manually: `source ~/.zshrc && zsh-system-update --dry-run --verbose`
5. Submit a pull request

### Testing Framework

The plugin includes a comprehensive testing framework with enhanced test runner:

**Test Execution Options:**
```bash
./test                    # Full comprehensive test suite (17s)
./test --unit-only        # Unit tests only (32 tests, 5s)
./test --integration-only # Integration tests only (38 tests, 13s)
./test --lint-only        # Code quality linting (14 files, 1s)
```

**Test Coverage:**
- **Total Tests**: 70 (38 integration + 32 unit tests)
- **Code Quality**: 14 shell files linted (0 errors, 13 minor warnings)
- **Success Rate**: 100% pass rate across all test suites
- **Enhanced Reporting**: Professional output with execution timing and visual progress

### Project Structure

```
zsh-system-update/
├── zsh-system-update.plugin.zsh    # Main plugin entry point
├── lib/
│   ├── managers/                   # Package manager implementations
│   │   ├── apt-manager.zsh        # APT package management
│   │   ├── conda-manager.zsh      # Conda environment management
│   │   ├── pip-manager.zsh        # pip package management
│   │   └── flatpak-manager.zsh    # Flatpak application management
│   └── utils/
│       └── output.zsh             # Color output and messaging utilities
├── tests/                          # Comprehensive test suite
│   ├── unit/                      # Unit tests for manager modules
│   │   ├── test-apt-manager.sh    # APT manager unit tests
│   │   ├── test-conda-manager.sh  # Conda manager unit tests
│   │   ├── test-pip-manager.sh    # Pip manager unit tests
│   │   └── test-flatpak-manager.sh # Flatpak manager unit tests
│   ├── run-unit-tests.sh          # Professional unit test runner
│   ├── test-utils.sh              # Shared testing utilities
│   └── test-zsh-system-update.sh  # Integration test suite
└── docs/                          # Additional documentation
```

## License

MIT License - see LICENSE file for details.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for detailed version history.

### Latest Changes
- **v0.3.6**: Fixed conda environment glob pattern error for empty environments directory
- **v0.3.5**: Documentation accuracy improvements - aligned cache thresholds, realistic performance claims, removed redundant features
- **v0.3.4**: Cache management commands (`--clear-cache`, `--clear-all-cache`, `--list-cache`) with comprehensive test coverage
- **v0.3.3**: Unified cache system with configurable thresholds and expanded test suite (51 total tests)
- **v0.3.2**: Comprehensive test suite enhancement with 70 total tests
- **v0.3.1**: Hook guard protection to prevent undesired execution contexts

## Related Projects

- [oh-my-zsh](https://github.com/ohmyzsh/ohmyzsh) - The framework this plugin extends
- [flatpak](https://flatpak.org/) - Application distribution framework
- [conda](https://docs.conda.io/) - Package and environment management
- [pip](https://pip.pypa.io/) - Python package installer

---

**Made with ❤️ for efficient system maintenance**
