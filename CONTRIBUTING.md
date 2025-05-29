# Contributing to zsh-system-update

Thank you for your interest in contributing to zsh-system-update! This document provides guidelines and information for contributors.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Making Changes](#making-changes)
- [Testing](#testing)
- [Submitting Changes](#submitting-changes)
- [Reporting Issues](#reporting-issues)
- [Style Guidelines](#style-guidelines)

## Code of Conduct

This project follows a simple code of conduct: be respectful, constructive, and collaborative. We welcome contributions from everyone regardless of experience level.

## Getting Started

### Prerequisites

- Linux/Unix environment (tested on Linux Mint/Ubuntu)
- zsh shell with oh-my-zsh installed
- Basic familiarity with shell scripting
- Git for version control

### Areas for Contribution

We welcome contributions in several areas:

- **Bug fixes** - Fix issues with existing functionality
- **Performance improvements** - Optimize caching or execution speed
- **New features** - Add support for new package managers or options
- **Documentation** - Improve README, add examples, fix typos
- **Testing** - Add test cases or improve test coverage
- **Platform support** - Extend support to other Linux distributions

## Development Setup

1. **Fork the repository** on GitHub

2. **Clone your fork locally:**
   ```bash
   git clone https://github.com/yourusername/zsh-system-update.git
   cd zsh-system-update
   ```

3. **Install the plugin for testing:**
   ```bash
   # Link to your oh-my-zsh plugins directory
   ln -sf "$(pwd)" ~/.oh-my-zsh/custom/plugins/zsh-system-update
   
   # Add to ~/.zshrc plugins list
   # plugins=(... zsh-system-update)
   
   # Reload shell
   source ~/.zshrc
   ```

4. **Create a branch for your changes:**
   ```bash
   git checkout -b feature/your-feature-name
   # or
   git checkout -b fix/issue-description
   ```

## Making Changes

### File Structure

The main plugin code is in `zsh-system-update.plugin.zsh`. Key sections include:

- **Function definitions** - Helper functions for colors, command execution
- **Caching logic** - Time-based update decisions
- **Update functions** - APT, Conda, and pip update logic  
- **Argument parsing** - Command-line option handling
- **Main execution** - Orchestration of update process

### Coding Standards

- **Use local variables** to avoid namespace pollution
- **Follow existing naming conventions** (snake_case for functions, CAPS for constants)
- **Add comments** for complex logic or non-obvious behavior
- **Handle errors gracefully** with appropriate fallbacks
- **Maintain backward compatibility** when possible

### Key Principles

1. **Performance first** - Avoid unnecessary operations
2. **Safe defaults** - Prefer cautious behavior over aggressive optimization
3. **Clear feedback** - Provide informative output to users
4. **Flexible options** - Allow users to customize behavior

## Testing

### Manual Testing

Always test your changes manually:

```bash
# Test dry-run mode
zsh-system-update --dry-run --verbose

# Test specific components
zsh-system-update --apt-only --verbose
zsh-system-update --conda-only --verbose

# Test edge cases
zsh-system-update --force-apt-update --force-conda-update

# Test error handling
# (temporarily rename conda binary, etc.)
```

### Test Environments

Consider testing in:
- Fresh conda installations
- Systems with/without conda
- Different Linux distributions (if possible)
- Various network conditions

### Performance Testing

For performance changes, measure before and after:

```bash
# Time full execution
time zsh-system-update --verbose

# Test caching behavior
zsh-system-update --verbose  # First run
zsh-system-update --verbose  # Second run (should be faster)
```

## Submitting Changes

### Before Submitting

1. **Test thoroughly** - Ensure your changes work as expected
2. **Update documentation** - Modify README.md if adding features
3. **Update CHANGELOG.md** - Add entry under "Unreleased" section
4. **Check code style** - Follow existing patterns and conventions

### Pull Request Process

1. **Commit your changes:**
   ```bash
   git add .
   git commit -m "feat: add support for XYZ package manager"
   # or
   git commit -m "fix: resolve caching issue with conda detection"
   ```

2. **Push to your fork:**
   ```bash
   git push origin feature/your-feature-name
   ```

3. **Create a Pull Request** on GitHub with:
   - Clear title describing the change
   - Detailed description of what was changed and why
   - Any testing performed
   - Screenshots/output if relevant

### Commit Message Format

Use conventional commits format:

- `feat:` - New features
- `fix:` - Bug fixes
- `docs:` - Documentation changes
- `perf:` - Performance improvements
- `refactor:` - Code refactoring
- `test:` - Test additions/changes

## Reporting Issues

### Bug Reports

When reporting bugs, please include:

- **System information** (OS, zsh version, oh-my-zsh version)
- **Plugin version** or commit hash
- **Steps to reproduce** the issue
- **Expected vs actual behavior**
- **Error messages** or output (use `--verbose` flag)
- **Relevant configuration** (conda setup, etc.)

### Feature Requests

For new features, please describe:

- **Use case** - Why is this feature needed?
- **Proposed solution** - How should it work?
- **Alternatives considered** - Other approaches you've thought of
- **Implementation ideas** - If you have technical suggestions

## Style Guidelines

### Shell Scripting

- Use `local` for function variables
- Quote variables: `"$variable"` not `$variable`
- Use `[[ ]]` for conditionals, not `[ ]`
- Prefer explicit over clever code
- Use meaningful variable names

### Documentation

- Use clear, concise language
- Include examples for new features
- Update help text for new options
- Follow existing formatting patterns

### Comments

```bash
# Good: Explains why, not what
# Use absolute path to avoid function recursion issues
local conda_cmd="/home/cli/miniconda3/bin/conda"

# Less helpful: Just describes what code does
# Set conda command variable
local conda_cmd="/home/cli/miniconda3/bin/conda"
```

## Questions or Help?

- **Open an issue** for questions about contributing
- **Check existing issues** to see if your question was already answered
- **Start with small changes** to get familiar with the codebase

Thank you for contributing to zsh-system-update! 🎉