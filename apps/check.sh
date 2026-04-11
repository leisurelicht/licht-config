#!/bin/bash

set -e

repo_root=$(
	cd "$(dirname "${0}")/.." || exit
	pwd
)

fail() {
	echo "[FAIL] $1"
	exit 1
}

check_shell_syntax() {
	echo "[Check] Shell syntax"
	bash -n "${repo_root}/install.sh"
	bash -n "${repo_root}/uninstall.sh"
	bash -n "${repo_root}/apps/brew.sh"
	bash -n "${repo_root}/apps/for_claude.sh"
}

check_submodule_status() {
	echo "[Check] Submodule status"
	if ! git -C "${repo_root}" submodule status >/dev/null; then
		fail "git submodule status failed"
	fi
}

check_stale_paths() {
	echo "[Check] Stale path references"
	if rg -n 'installed/|brew_install\.sh|brew_cask_install\.sh|\\bbak/|back-up/|\\bconfig/' \
		"${repo_root}/README.md" \
		"${repo_root}/AGENTS.md" >/dev/null; then
		fail "Found stale path references in README.md or AGENTS.md"
	fi
}

check_shell_syntax
check_submodule_status
check_stale_paths

echo "[OK] All checks passed"
