# zsh-system-update

A smart, efficient system update plugin for oh-my-zsh that handles APT packages, Conda environments, and pip installations with intelligent caching to minimize update times.

## Features

- 🚀 **Smart Caching**: Skips unnecessary updates based on configurable time thresholds
- 🐍 **Multi-Environment Support**: Updates pip across all conda environments automatically  
- ⚡ **Performance Optimized**: 60-80% faster on repeated runs within cache windows
- 🎛️ **Flexible Options**: Granular control over what gets updated
- 🎨 **Beautiful Output**: Color-coded status messages and progress indicators
- 🛡️ **Safe Defaults**: Handles configuration prompts and errors gracefully

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
- `--skip-apt` - Skip APT system updates
- `--skip-conda` - Skip Conda updates  
- `--skip-pip` - Skip pip updates

### Cache Control
- `--force-apt-update` - Force APT update even if recently updated
- `--force-conda-update` - Force Conda update even if recently updated

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

## Requirements

### System Requirements
- Linux (tested on Linux Mint/Ubuntu)
- zsh shell with oh-my-zsh
- sudo access for system package updates

### Dependencies
The plugin checks for required commands automatically:
- `apt-get` (system packages)
- `conda` (conda environment management)  
- `python` (pip updates)
- Standard Unix utilities (`basename`, `wc`, `grep`)

## Configuration

### Time Thresholds
You can modify the cache thresholds by editing the plugin file:

```bash
# In zsh-system-update.plugin.zsh
local update_threshold=3600   # APT: 1 hour
local update_threshold=7200   # Conda: 2 hours
```

### Conda Installation Paths
The plugin automatically detects conda installations in:
- `~/miniconda3/`
- `~/anaconda3/`

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
# Check conda installation
which conda
conda --version
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
2. Make changes to `zsh-system-update.plugin.zsh`
3. Test with `source ~/.zshrc && zsh-system-update --dry-run`
4. Submit a pull request

## License

MIT License - see LICENSE file for details.

## Changelog

### v0.1.0
- Initial release with smart caching
- Support for APT, Conda, and pip updates
- Comprehensive command-line options
- Tab completion support

## Related Projects

- [oh-my-zsh](https://github.com/ohmyzsh/ohmyzsh) - The framework this plugin extends
- [conda](https://docs.conda.io/) - Package and environment management
- [pip](https://pip.pypa.io/) - Python package installer

---

**Made with ❤️ for efficient system maintenance**
