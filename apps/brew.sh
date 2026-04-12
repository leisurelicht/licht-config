#!/bin/bash

set -e

mode="${1}"

script_dir=$(
	cd "$(dirname "${0}")" || exit
	pwd
)
# shellcheck source=../lib/log.sh
source "${script_dir}/../lib/log.sh"
# shellcheck source=brew_lists.sh
source "${script_dir}/brew_lists.sh"

init_log_style

if ! command -v brew >/dev/null 2>&1; then
	log_error "Homebrew is not installed"
	log_info "Install it from: https://brew.sh"
	exit 1
fi

if ! is_valid_brew_mode "${mode}"; then
	log_error "Unknown mode: ${mode}"
	log_info "Usage: ./apps/brew.sh [all|formula|cask]"
	exit 1
fi

ensure_brew_tap() {
	local tap_name=$1

	if [[ -z "${tap_name}" ]]; then
		return 0
	fi

	if brew tap | grep -Fxq "${tap_name}"; then
		return 0
	fi

	log_step "Tapping ${tap_name}"
	if ! brew tap "${tap_name}"; then
		log_error "Failed to tap ${tap_name}"
		return 1
	fi
}

if [[ "${mode}" == "all" || "${mode}" == "formula" ]]; then
	log_info "Installing ${#BREW_PACKAGES[@]} packages..."

	for pkg in "${BREW_PACKAGES[@]}"; do
		if brew list --formula "$pkg" >/dev/null 2>&1; then
			log_ok "$pkg already installed"
		else
			tap_name=""
			if tap_name=$(required_tap_for_brew_item "formula" "$pkg"); then
				if ! ensure_brew_tap "${tap_name}"; then
					continue
				fi
			fi

			log_step "Installing $pkg"
			if ! brew install "$pkg"; then
				log_error "Failed to install $pkg"
			fi
		fi
	done
fi

if [[ "${mode}" == "all" || "${mode}" == "cask" ]]; then
	log_info "Installing ${#BREW_CASKS[@]} casks..."

	for cask in "${BREW_CASKS[@]}"; do
		if brew list --cask "$cask" >/dev/null 2>&1; then
			log_ok "$cask already installed"
		else
			tap_name=""
			if tap_name=$(required_tap_for_brew_item "cask" "$cask"); then
				if ! ensure_brew_tap "${tap_name}"; then
					continue
				fi
			fi

			log_step "Installing $cask"
			if ! brew install --cask "$cask"; then
				log_error "Failed to install $cask"
			fi
		fi
	done
fi

log_ok "Done"
