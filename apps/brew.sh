#!/bin/bash

set -e

mode="${1}"

if ! command -v brew >/dev/null 2>&1; then
	echo "Error: Homebrew is not installed"
	echo "Install it from: https://brew.sh"
	exit 1
fi

if [[ "${mode}" != "all" && "${mode}" != "formula" && "${mode}" != "cask" ]]; then
	echo "Error: Unknown mode: ${mode}"
	echo "Usage: ./apps/brew.sh [all|formula|cask]"
	exit 1
fi

packages=(
	"mycli"
	"wget"
	"git"
	"tig"
	"cloc"
	"ctop"
	"gibo"
	"bat"
	"lazygit"
	"pyenv"
	"zoxide"
	"trash"
	"htop"
	"bottom"
	"nmap"
	"uv"
)

casks=(
	"google-chrome"
	"cheatsheet"
	"itsycal"
	"browserosaurus"
	"thor"
	"iterm2"
	"spotify"
	"devtoys"
	"cursor"
	"ghostty"
	"obsidian"
	"claude-code"
	"geph"
	"visual-studio-code"
	"codex"
	"codex-app"
	"codeisland"
	"masscode"
)

if [[ "${mode}" == "all" || "${mode}" == "formula" ]]; then
	echo "Installing ${#packages[@]} packages..."

	for pkg in "${packages[@]}"; do
		if brew list --formula "$pkg" >/dev/null 2>&1; then
			echo "[OK] $pkg already installed"
		else
			echo "[Installing] $pkg"
			if ! brew install "$pkg"; then
				echo "[Error] Failed to install $pkg"
			fi
		fi
	done
fi

if [[ "${mode}" == "all" || "${mode}" == "cask" ]]; then
	echo "Installing ${#casks[@]} casks..."

	for cask in "${casks[@]}"; do
		if brew list --cask "$cask" >/dev/null 2>&1; then
			echo "[OK] $cask already installed"
		else
			echo "[Installing] $cask"
			if ! brew install --cask "$cask"; then
				echo "[Error] Failed to install $cask"
			fi
		fi
	done
fi

echo "Done!"
