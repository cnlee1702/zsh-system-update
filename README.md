# zsh-system-update

A smart, efficient system update plugin for oh-my-zsh that handles APT packages, Conda environments, pip installations, and Flatpak applications with intelligent caching to minimize update times.

## Features

- 🚀 **Smart Caching**: Skips unnecessary updates based on configurable time thresholds
- 📦 **Multi-Package Manager Support**: Updates APT, Conda, pip, and Flatpak applications
- 🐍 **Multi-Environment Support**: Updates pip across all conda environments automatically  
- ⚡ **Performance Optimized**: 60-80% faster on repeated runs within cache windows
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
- **Conda updates**: Cached for 2 hours (larger operations, less frequent updates)
- **Flatpak updates**: Cached for 2 hours (similar to Conda, less frequent updates)
- **Pip updates**: Always run (fast operations, checked per environment)

### Performance Impact

| Scenario | Without Caching | With Caching | Time Saved |
|----------|-----------------|--------------|------------|
| First run | 3-4 minutes | 3-4 minutes | 0% |
| Within cache window | 3-4 minutes | 30-60 seconds | **75-85%** |
| Force updates | 3-4 minutes | 3-4 minutes | 0% |

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

### Time Thresholds
You can modify the cache thresholds by editing the respective manager files:

```bash
# In lib/managers/apt-manager.zsh
local update_threshold=3600   # APT: 1 hour

# In lib/managers/conda-manager.zsh  
local update_threshold=7200   # Conda: 2 hours

# In lib/managers/flatpak-manager.zsh
local cache_threshold=7200    # Flatpak: 2 hours
```

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
3. Test with `source ~/.zshrc && zsh-system-update --dry-run --verbose`
4. Run specific manager tests: `zsh-system-update --[manager]-only --dry-run --verbose`
5. Submit a pull request

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
├── tests/                          # Test suite
└── docs/                          # Additional documentation
```

## License

MIT License - see LICENSE file for details.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for detailed version history.

### Latest Changes
- **v0.2.0**: Added Flatpak support, enhanced caching, modular architecture
- **v0.1.0**: Initial release with APT, Conda, and pip support

## Related Projects

- [oh-my-zsh](https://github.com/ohmyzsh/ohmyzsh) - The framework this plugin extends
- [conda](https://docs.conda.io/) - Package and environment management
- [pip](https://pip.pypa.io/) - Python package installer

---

**Made with ❤️ for efficient system maintenance**
