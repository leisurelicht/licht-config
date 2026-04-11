#!/bin/bash

set -e

if ! command -v brew >/dev/null 2>&1; then
	echo "Error: Homebrew is not installed"
	echo "Install it from: https://brew.sh"
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
	"trash"
	"htop"
	"bottom"
	"nmap"
)

casks=(
	"google-chrome"
	"cheatsheet"
	"itsycal"
	"browserosaurus"
	"thor"
	"iterm2"
	"devtoys"
	"cursor"
	"masscode"
)

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

echo "Done!"
