#!/bin/bash

set -e

script_dir=$(
	cd "$(dirname "${0}")" || exit
	pwd
)
# shellcheck source=lib/log.sh
source "${script_dir}/lib/log.sh"
# shellcheck source=../apps/for_claude_lists.sh
source "${script_dir}/../apps/for_claude_lists.sh"

init_log_style

if ! command -v brew >/dev/null 2>&1; then
	log_error "Homebrew is not installed"
	log_info "Install it from: https://brew.sh"
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

	log_step "Adding tap: ${tap_name}"
	if ! brew tap "${tap_name}"; then
		log_error "Failed to add tap: ${tap_name}"
		return 1
	fi
}

for item in "${CLAUDE_BREW_ITEMS[@]}"; do
	if ! parse_brew_item "${item}"; then
		log_error "Invalid Claude brew item format: ${item}"
		exit 1
	fi

	if ! ensure_brew_tap "${BREW_ITEM_TAP}"; then
		exit 1
	fi

	if [[ "${BREW_ITEM_TYPE}" == "formula" ]]; then
		if brew list --formula "${BREW_ITEM_NAME}" >/dev/null 2>&1; then
			log_ok "${BREW_ITEM_NAME} already installed"
		else
			log_step "Installing formula ${BREW_ITEM_NAME}"
			if ! brew install "${BREW_ITEM_NAME}"; then
				log_error "Failed to install ${BREW_ITEM_NAME}"
				exit 1
			fi
		fi
	else
		if brew list --cask "${BREW_ITEM_NAME}" >/dev/null 2>&1; then
			log_ok "${BREW_ITEM_NAME} already installed"
		else
			log_step "Installing cask ${BREW_ITEM_NAME}"
			if ! brew install --cask "${BREW_ITEM_NAME}"; then
				log_error "Failed to install ${BREW_ITEM_NAME}"
				exit 1
			fi
		fi
	fi
done

log_ok "Done"
