#!/bin/bash

set -e

mode="${1}"

script_dir=$(
	cd "$(dirname "${0}")" || exit
	pwd
)
# shellcheck source=../lib/log.sh
source "${script_dir}/../lib/log.sh"

init_log_style

if ! command -v brew >/dev/null 2>&1; then
	log_error "Homebrew is not installed"
	log_info "Install it from: https://brew.sh"
	exit 1
fi

if [[ "${mode}" != "all" && "${mode}" != "formula" && "${mode}" != "cask" ]]; then
	log_error "Unknown mode: ${mode}"
	log_info "Usage: ./apps/brew.sh [all|formula|cask]"
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
	log_info "Installing ${#packages[@]} packages..."

	for pkg in "${packages[@]}"; do
		if brew list --formula "$pkg" >/dev/null 2>&1; then
			log_ok "$pkg already installed"
		else
			log_step "Installing $pkg"
			if ! brew install "$pkg"; then
				log_error "Failed to install $pkg"
			fi
		fi
	done
fi

if [[ "${mode}" == "all" || "${mode}" == "cask" ]]; then
	log_info "Installing ${#casks[@]} casks..."

	for cask in "${casks[@]}"; do
		if brew list --cask "$cask" >/dev/null 2>&1; then
			log_ok "$cask already installed"
		else
			log_step "Installing $cask"
			if ! brew install --cask "$cask"; then
				log_error "Failed to install $cask"
			fi
		fi
	done
fi

log_ok "Done"
