# AGENTS.md

## Project Overview

Personal dotfiles repository for managing shell, editor, and terminal configurations across macOS and Linux systems.

## Directory Structure

```
.
├── install.sh          # Main installation script
├── uninstall.sh        # Uninstallation script
├── configs/            # Dotfile configurations
│   ├── zsh/            # Zsh configuration
│   │   ├── zshrc       # Main zsh config (sourced via symlink)
│   │   ├── aliasrc     # Aliases and functions
│   │   ├── export_env  # Environment variables (private)
│   │   ├── fzf.zsh     # FZF custom config
│   │   └── p10k.zsh    # Powerlevel10k theme config
│   ├── tmux/           # Tmux configuration
│   │   ├── tmux.conf   # Main tmux config
│   │   └── mini.conf   # Minimal config for quick setup
│   ├── vi/             # Vim/Neovim configuration
│   │   ├── vim/vimrc   # Vim config
│   │   └── nvim/       # Neovim config (git submodule)
│   └── ghostty/        # Ghostty configuration
├── installed/          # Helper scripts
│   └── brew_install.sh
└── backups/            # Backup directory (gitignored)
```

## Commands

### Installation

```bash
./install.sh [all|zsh|tmux|vim|neovim]
```

### Uninstallation

```bash
./uninstall.sh [all|zsh|tmux|vim|neovim]
```

### Linting

```bash
# Shell scripts
shellcheck install.sh uninstall.sh installed/*.sh

# Shell format (if shfmt installed)
shfmt -d install.sh uninstall.sh
```

### Prerequisites

- [shellcheck](https://github.com/koalaman/shellcheck) for linting
- [shfmt](https://github.com/mvdan/sh) for formatting

## Code Style

### Shell Scripts

- Indentation: Tabs
- Shebang: `#!/bin/bash` or `#!/usr/bin/env bash`
- Error handling: Check command exit codes
- Follow Google Shell Style Guide principles

### Vim Configuration

- Indentation: 2 spaces
- Use augroups for autocommands
- Plugins managed via vim-plug

### Tmux Configuration

- Use vi mode keys
- Custom status line with Catppuccin colors

### Zsh Configuration

- Plugins managed via zinit
- Aliases in separate file (aliasrc)
- Private env vars in export_env (not committed)

## Commit Convention

Format: `type: description`

Types:
- `fix`: Bug fixes, corrections
- `feat`: New features
- `docs`: Documentation changes
- `refactor`: Code refactoring
- `chore`: Maintenance tasks

Examples:
```
fix: correct fzf installation path
feat: add docker cleanup aliases
docs: update README installation instructions
```

## Important Notes

1. **Neovim config** (`configs/vi/nvim`) is a git submodule pointing to a separate repository

2. **Backup files** are stored in `backups/` directory (gitignored)

3. **Symlinks**: Install script creates symlinks from repo files to home directory:
   - `~/.zshrc` → `./configs/zsh/zshrc`
   - `~/.tmux.conf` → `./configs/tmux/tmux.conf`
   - `~/.vimrc` → `./configs/vi/vim/vimrc`
   - `~/.config/nvim` → `./configs/vi/nvim`
   - `~/.p10k.zsh` → `./configs/zsh/p10k.zsh`

4. **Platform support**: Primary target is macOS, with Linux support for most features

5. **Do not review** `configs/vi/nvim/` directory (external submodule)
