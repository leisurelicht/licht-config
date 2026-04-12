#!/bin/bash

set -e

script_dir=$(
	cd "$(dirname "${0}")" || exit
	pwd
)
# shellcheck source=../lib/log.sh
source "${script_dir}/../lib/log.sh"

repo_root=$(
	cd "${script_dir}/.." || exit
	pwd
)

fail() {
	log_error "$1"
	exit 1
}

check_shell_syntax() {
	log_step "Shell syntax"
	bash -n "${repo_root}/install.sh"
	bash -n "${repo_root}/uninstall.sh"
	bash -n "${repo_root}/apps/brew.sh"
	bash -n "${repo_root}/apps/brew_lists.sh"
	bash -n "${repo_root}/apps/for_claude.sh"
}

check_submodule_status() {
	log_step "Submodule status"
	if ! git -C "${repo_root}" submodule status >/dev/null; then
		fail "git submodule status failed"
	fi
}

check_stale_paths() {
	log_step "Stale path references"
	if rg -n 'installed/|brew_install\.sh|brew_cask_install\.sh|\\bbak/|back-up/|\\bconfig/' \
		"${repo_root}/README.md" \
		"${repo_root}/AGENTS.md" >/dev/null; then
		fail "Found stale path references in README.md or AGENTS.md"
	fi
}

init_log_style
log_info "Run repo checks"
check_shell_syntax
check_submodule_status
check_stale_paths

log_ok "All checks passed"
