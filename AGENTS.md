# AGENTS.md

## Project Overview

Personal dotfiles repository for managing shell, terminal, editor, and app configuration across macOS and Linux systems.

This repo is primarily a symlink-based config installer:
- source files live in `configs/`
- install script implementations live in `scripts/`
- shared app install lists live in `apps/`
- user files are linked into `$HOME`
- previous user files are moved into `backups/`

## Current Layout

```text
.
├── apps/
│   ├── brew_lists.sh
│   └── for_claude_lists.sh
├── scripts/
│   ├── brew.sh
│   ├── install.sh
│   ├── uninstall.sh
│   ├── check.sh
│   ├── for_claude.sh
│   └── lib/
│       └── log.sh
├── configs/
│   ├── ghostty/
│   ├── tmux/
│   ├── vi/
│   │   ├── vim/
│   │   └── nvim/      # git submodule
│   └── zsh/
├── backups/
├── README.md
└── .gitmodules
```

## Commands

### Main entry points

```bash
./launcher.sh
./scripts/install.sh all [all|formula|cask]
./scripts/install.sh --apps [all|brew|claude] [all|formula|cask]
./scripts/install.sh --conf [all|zsh|tmux|vim|neovim|ghostty]
./scripts/uninstall.sh all
./scripts/uninstall.sh --apps [brew|claude] [all|formula|cask]
./scripts/uninstall.sh --conf [all|zsh|tmux|vim|neovim|ghostty]
```

### Helper scripts

```bash
./apps/brew_lists.sh
./apps/for_claude_lists.sh
./scripts/brew.sh
./scripts/check.sh
./scripts/for_claude.sh
```

### Validation

```bash

bash -n launcher.sh
bash -n scripts/install.sh
bash -n scripts/uninstall.sh
bash -n scripts/check.sh

# Optional, if installed
shellcheck launcher.sh scripts/*.sh apps/*.sh
shfmt -d launcher.sh scripts/*.sh apps/*.sh
```

### Submodule setup

```bash
git submodule update --init --recursive
```

## Source To Target Mapping

These mappings are the core contract of the repo. When changing paths, update them consistently everywhere.

| Repo source | Home target |
| --- | --- |
| `configs/zsh/zshrc` | `~/.zshrc` |
| `configs/zsh/p10k.zsh` | `~/.p10k.zsh` |
| `configs/tmux/tmux.conf` | `~/.tmux.conf` |
| `configs/vi/vim/vimrc` | `~/.vimrc` |
| `configs/vi/nvim` | `~/.config/nvim` |
| `configs/ghostty` | `~/.config/ghostty` |

Backup location:
- repo backup directory: `backups/`

## High-Frequency Change Areas

### 1. Config path changes

If you move or rename anything under `configs/`, check all of:
- `scripts/install.sh`
- `scripts/uninstall.sh`
- `README.md`
- `AGENTS.md`
- `.gitmodules` when `configs/vi/nvim` is involved

### 2. Neovim submodule changes

`configs/vi/nvim` is a git submodule.

The Neovim configuration is no longer actively updated in this repo.
Treat it as frozen unless the user explicitly asks for a submodule-related change.

If its path changes, you must update both:
- `.gitmodules`
- the git index gitlink entry

Useful checks:

```bash
git ls-files --stage | grep nvim
git submodule status
```

### 3. Backup behavior changes

If install/uninstall backup paths change, update both scripts and the documentation together.

### 4. Helper script changes

If files under `apps/` or `scripts/` are renamed or added, update:
- `README.md`
- `AGENTS.md`
- lint commands if needed

## Working Rules

### Shell style

- Use tabs for indentation in shell scripts.
- Keep shebangs as `#!/bin/bash` or `#!/usr/bin/env bash`.
- Preserve current script style unless there is a good reason to normalize more broadly.
- Prefer narrow edits over style churn.

### File handling

- Treat this repo as user-owned configuration.
- Do not remove or overwrite unrelated user changes.
- Keep backup behavior intact unless the task explicitly changes backup semantics.

### Repo-specific behavior

- `scripts/install.sh` should be rerunnable without mutating repo-owned config directories.
- `scripts/uninstall.sh` should only remove managed symlinks and restore backups conservatively.
- `ghostty`, `nvim`, and other directory symlinks need careful handling on macOS because `ln` can follow directory symlinks.

## Do Not Touch By Default

- Do not review or edit `configs/vi/nvim/` contents unless the user explicitly asks.
- Do not proactively modernize, refactor, or update the Neovim configuration.
- Do not change submodule contents when the task is only about path/layout/doc updates.
- Do not modify files under `$HOME` as part of a repo-only change unless the user explicitly asks to run install/uninstall behavior.
- Do not convert shell indentation away from tabs unless the file is already being reformatted intentionally.

## Done Criteria

For any path/layout/script change, the work is not complete until all relevant items below are true:

1. `bash -n scripts/install.sh` and `bash -n scripts/uninstall.sh` pass.
2. No docs still reference removed paths or old directory names.
3. If `configs/vi/nvim` was touched or moved:
   - `.gitmodules` is correct
   - `git submodule status` works
   - `git ls-files --stage` shows the correct gitlink path
4. If helper scripts changed, their paths in docs match the repo.

## Common Tasks

### Add a new managed config

1. Add files under `configs/<name>/`.
2. Update `scripts/install.sh` symlink and backup logic.
3. Update `scripts/uninstall.sh` restore logic.
4. Update `README.md` and `AGENTS.md`.

### Move a config directory

1. Move the files.
2. Update all path references in scripts and docs.
3. If a submodule is involved, update `.gitmodules` and the git index.
4. Run the validation commands.

### Add a brew package or app

1. Edit `apps/brew_lists.sh`.
2. Add items to `BREW_ITEMS` using `type:name[:tap]`.
3. For Claude-specific app installs, edit `apps/for_claude_lists.sh` and add items to `CLAUDE_BREW_ITEMS`.
4. Keep the list changes scoped; do not reshuffle unrelated entries.

### Review this repo

Focus on:
- broken path migrations
- submodule consistency
- symlink idempotency
- backup/restore regressions
- stale documentation after layout changes
