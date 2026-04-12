#!/bin/bash

BREW_PACKAGES=(
	"mycli"
	"wget"
	"git"
	"tig"
	"cloc"
	"ctop"
	"gibo"
	"bat"
	"lazygit"
	"zoxide"
	"trash"
	"htop"
	"bottom"
	"nmap"
	"uv"
)

BREW_CASKS=(
	"google-chrome"
	"cheatsheet"
	"itsycal"
	"browserosaurus"
	"thor"
	"iterm2"
	"spotify"
	"devtoys"
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

# Format: "<formula|cask>:<name>:<tap>"
# Example:
# "formula:im-select:daipeihust/tap"
BREW_TAP_RULES=(
)

is_valid_brew_mode() {
	local mode=$1
	[[ "${mode}" == "all" || "${mode}" == "formula" || "${mode}" == "cask" ]]
}

required_tap_for_brew_item() {
	local item_type=$1
	local item_name=$2
	local rule
	local rule_type
	local rule_name
	local rule_tap

	for rule in "${BREW_TAP_RULES[@]}"; do
		rule_type=${rule%%:*}
		rule_name=${rule#*:}
		rule_name=${rule_name%%:*}
		rule_tap=${rule##*:}

		if [[ "${rule_type}" == "${item_type}" && "${rule_name}" == "${item_name}" ]]; then
			printf '%s\n' "${rule_tap}"
			return 0
		fi
	done

	return 1
}
