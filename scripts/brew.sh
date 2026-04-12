#!/bin/bash

set -e

mode="${1}"

script_dir=$(
	cd "$(dirname "${0}")" || exit
	pwd
)
# shellcheck source=lib/log.sh
source "${script_dir}/lib/log.sh"
# shellcheck source=../apps/brew_lists.sh
source "${script_dir}/../apps/brew_lists.sh"

init_log_style

if ! command -v brew >/dev/null 2>&1; then
	log_error "Homebrew is not installed"
	log_info "Install it from: https://brew.sh"
	exit 1
fi

is_valid_brew_mode() {
	local mode_name=$1
	[[ "${mode_name}" == "all" || "${mode_name}" == "formula" || "${mode_name}" == "cask" ]]
}

if ! is_valid_brew_mode "${mode}"; then
	log_error "Unknown mode: ${mode}"
	log_info "Usage: ./scripts/brew.sh [all|formula|cask]"
	exit 1
fi

parse_brew_item() {
	local item=$1
	local rest

	BREW_ITEM_TYPE=${item%%:*}
	rest=${item#*:}
	if [[ "${rest}" == "${item}" ]]; then
		return 1
	fi

	BREW_ITEM_NAME=${rest%%:*}
	if [[ "${rest}" == *:* ]]; then
		BREW_ITEM_TAP=${rest#*:}
	else
		BREW_ITEM_TAP=""
	fi

	if [[ -z "${BREW_ITEM_TYPE}" || -z "${BREW_ITEM_NAME}" ]]; then
		return 1
	fi

	if [[ "${BREW_ITEM_TYPE}" != "formula" && "${BREW_ITEM_TYPE}" != "cask" ]]; then
		return 1
	fi

	return 0
}

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

is_item_enabled_for_mode() {
	local mode_name=$1
	local item_type=$2

	case "${mode_name}" in
	all) return 0 ;;
	formula) [[ "${item_type}" == "formula" ]] ;;
	cask) [[ "${item_type}" == "cask" ]] ;;
	*) return 1 ;;
	esac
}

is_item_installed() {
	local item_type=$1
	local item_name=$2

	if [[ "${item_type}" == "formula" ]]; then
		brew list --formula "${item_name}" >/dev/null 2>&1
	else
		brew list --cask "${item_name}" >/dev/null 2>&1
	fi
}

install_item() {
	local item_type=$1
	local item_name=$2

	if [[ "${item_type}" == "formula" ]]; then
		brew install "${item_name}"
	else
		brew install --cask "${item_name}"
	fi
}

target_count=0
for item in "${BREW_ITEMS[@]}"; do
	if ! parse_brew_item "${item}"; then
		log_error "Invalid brew item format: ${item}"
		exit 1
	fi
	if is_item_enabled_for_mode "${mode}" "${BREW_ITEM_TYPE}"; then
		target_count=$((target_count + 1))
	fi
done

log_info "Installing ${target_count} brew item(s)..."
for item in "${BREW_ITEMS[@]}"; do
	if ! parse_brew_item "${item}"; then
		log_error "Invalid brew item format: ${item}"
		exit 1
	fi
	if ! is_item_enabled_for_mode "${mode}" "${BREW_ITEM_TYPE}"; then
		continue
	fi

	if is_item_installed "${BREW_ITEM_TYPE}" "${BREW_ITEM_NAME}"; then
		log_ok "${BREW_ITEM_NAME} already installed"
		continue
	fi

	if ! ensure_brew_tap "${BREW_ITEM_TAP}"; then
		continue
	fi

	log_step "Installing ${BREW_ITEM_TYPE} ${BREW_ITEM_NAME}"
	if ! install_item "${BREW_ITEM_TYPE}" "${BREW_ITEM_NAME}"; then
		log_error "Failed to install ${BREW_ITEM_TYPE} ${BREW_ITEM_NAME}"
	fi
done

log_ok "Done"
