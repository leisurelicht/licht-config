#!/bin/bash

set -e

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

# Add custom tap for dippy
if ! brew tap | grep -q "ldayton/dippy"; then
	log_step "Adding tap: ldayton/dippy"
	brew tap ldayton/dippy
fi

# Install dippy
if brew list --formula "dippy" >/dev/null 2>&1; then
	log_ok "dippy already installed"
else
	log_step "Installing dippy"
	if ! brew install dippy; then
		log_error "Failed to install dippy"
		exit 1
	fi
fi

log_ok "Done"
