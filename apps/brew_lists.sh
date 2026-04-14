#!/bin/bash

# Format: "<type>:<brew-name>[:<tap>]:::<post-install-cmd>"
# - type: "formula" or "cask"
# - brew-name: package name for brew install
# - tap: optional tap source
# - post-install-cmd: optional shell command(s) to run after installation
#   Multiple commands separated by ;;
#
# Examples:
# "formula:mycli"                         # basic install
# "formula:im-select:daipeihust/tap"      # with custom tap
# "formula:rtk:::rtk init -g"             # with post-install
# "formula:rtk:::rtk init -g;;rtk init -g --codex"  # multiple commands
BREW_ITEMS=(
	"formula:mycli"
	"formula:wget"
	"formula:git"
	"formula:tig"
	"formula:cloc"
	"formula:ctop"
	"formula:gibo"
	"formula:bat"
	"formula:lazygit"
	"formula:zoxide"
	"formula:trash"
	"formula:htop"
	"formula:bottom"
	"formula:nmap"
	"formula:uv"
	"formula:rtk:::rtk init -g --auto-patch;;rtk init -g --codex"
	"cask:google-chrome"
	"cask:itsycal"
	"cask:browserino:alexstrnik/browserino"
	"cask:thor"
	"cask:iterm2"
	"cask:spotify"
	"cask:ghostty"
	"cask:obsidian"
	"cask:claude-code"
	"cask:geph"
	"cask:visual-studio-code"
	"cask:codex"
	"cask:codex-app"
	"cask:codeisland"
	"cask:masscode"
)