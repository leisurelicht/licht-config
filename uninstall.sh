#!/usr/bin/env bash

fail() {
	echo "====> Error: $1"
	exit 1
}

fzf_config_start="# Fzf Custom Config"
fzf_config_end="# End Fzf Custom Config"

config_path=$(
	cd "$(dirname "${0}")" || exit
	pwd
)

print_usage() {
	cat <<'EOF'
Usage:
  ./uninstall.sh all
  ./uninstall.sh configs <all|zsh|tmux|vim|neovim|ghostty>
  ./uninstall.sh apps <brew|claude> <brew_mode>

Options:
  brew_mode: all | formula | cask

Examples:
  ./uninstall.sh configs zsh
  ./uninstall.sh apps brew cask
  ./uninstall.sh apps claude all
EOF
}

has() {
	command -v "$1" >/dev/null 2>&1
}

uninstall_apps() {
	local app=${1:-}
	local brew_mode=${2:-}

	if [[ -z "${app}" ]]; then
		print_usage
		exit 0
	fi

	if ! has brew; then
		echo "====> Error: [ brew ] is not installed."
		exit 1
	fi

	case "${app}" in
	brew)
		if [[ -z "${brew_mode}" ]]; then
			print_usage
			exit 0
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

		if [[ "${brew_mode}" != "all" && "${brew_mode}" != "formula" && "${brew_mode}" != "cask" ]]; then
			echo "====> Error: Unknown brew mode: ${brew_mode}"
			print_usage
			exit 1
		fi

		if [[ "${brew_mode}" == "all" || "${brew_mode}" == "formula" ]]; then
			for pkg in "${packages[@]}"; do
				if brew list --formula "$pkg" >/dev/null 2>&1; then
					echo "----> Uninstall brew formula [ ${pkg} ]"
					brew uninstall "$pkg" >/dev/null 2>&1 || true
				fi
			done
		fi

		if [[ "${brew_mode}" == "all" || "${brew_mode}" == "cask" ]]; then
			for cask in "${casks[@]}"; do
				if brew list --cask "$cask" >/dev/null 2>&1; then
					echo "----> Uninstall brew cask [ ${cask} ]"
					brew uninstall --cask "$cask" >/dev/null 2>&1 || true
				fi
			done
		fi
		;;
	claude)
		if brew list --formula "dippy" >/dev/null 2>&1; then
			echo "----> Uninstall brew formula [ dippy ]"
			brew uninstall "dippy" >/dev/null 2>&1 || true
		fi
		if brew tap | grep -q "^ldayton/dippy$"; then
			echo "----> Remove brew tap [ ldayton/dippy ]"
			brew untap "ldayton/dippy" >/dev/null 2>&1 || true
		fi
		;;
	*)
		echo "====> Error: Unknown apps parameter: ${app}"
		print_usage
		exit 1
		;;
	esac
}

remove_fzf_custom_config() {
	local target_file=$1
	local tmp_file
	local start_line
	local end_line

	if [[ ! -f "${target_file}" ]]; then
		return
	fi

	start_line=$(grep -nFx "${fzf_config_start}" "${target_file}" | head -n 1 | cut -d: -f1)
	if [[ -z "${start_line}" ]]; then
		return
	fi

	end_line=$(grep -nFx "${fzf_config_end}" "${target_file}" | tail -n 1 | cut -d: -f1)
	if [[ -n "${end_line}" && ${end_line} -ge ${start_line} ]]; then
		tmp_file=$(mktemp)
		sed "${start_line},${end_line}d" "${target_file}" >"${tmp_file}"
		mv "${tmp_file}" "${target_file}"
	else
		sed -i.bak "${start_line},\$d" "${target_file}"
		rm -f "${target_file}.bak"
	fi
}

first_existing_backup_path() {
	local primary_path=$1
	local legacy_path=$2

	if [[ -e "${primary_path}" ]]; then
		echo "${primary_path}"
	elif [[ -n "${legacy_path}" && -e "${legacy_path}" ]]; then
		echo "${legacy_path}"
	fi
}

remove_path() {
	local target_path=$1
	local description=$2
	shift 2

	if ! rm "$@" "${target_path}" >/dev/null 2>&1; then
		fail "Failed to remove ${description} [ ${target_path} ]."
	fi
}

move_path() {
	local source_path=$1
	local target_path=$2
	local description=$3

	if ! mv "${source_path}" "${target_path}" >/dev/null 2>&1; then
		fail "Failed to move ${description} from [ ${source_path} ] to [ ${target_path} ]."
	fi
}

primary=${1:-}
secondary=${2:-}

if [[ -z "${primary}" ]]; then
	print_usage
	exit 1
fi

case "${primary}" in
all)
	uninstall_apps "brew" "all"
	uninstall_apps "claude"
	set -- all
	;;
configs)
	if [[ -z "${secondary}" ]]; then
		print_usage
		exit 0
	fi
	set -- "${secondary}"
	;;
apps)
	uninstall_apps "${secondary}" "${3:-}"
	exit 0
	;;
*)
	echo "====> Error: Unknown parameter: ${primary}"
	print_usage
	exit 1
	;;
esac

commands=("all" "zsh" "tmux" "vim" "neovim" "ghostty")
command_found=0
for command in "${commands[@]}"; do
	if [[ "${command}" == "${1}" ]]; then
		command_found=1
		break
	fi
done

if [[ ${command_found} -ne 1 ]]; then
	echo "====> Error: Unknown parameter: ${1}"
	print_usage
	exit 1
fi

if [[ "${1}" == "all" || "${1}" == "tmux" ]]; then
	if [ -h ~/.tmux.conf ]; then
		echo "====> Remove tmux config file"
		remove_path ~/.tmux.conf "tmux config file"

		if [[ -f "${config_path}/backups/tmux.conf.bak" ]]; then
			echo "====> Move backup tmux config file"
			if [[ ! -f ~/.tmux.conf ]]; then
				move_path "${config_path}/backups/tmux.conf.bak" ~/.tmux.conf "tmux backup"
			fi
		fi

		echo "====> Delete tmux plugin"
		remove_path ~/.tmux "tmux plugin directory" -rf

		echo "====> Uninstall tmux config success"
	else
		echo "====> No tmux"
		if [[ "${1}" == "tmux" ]]; then
			exit 0
		fi
	fi
fi

if [[ "${1}" == "all" || "${1}" == "vim" ]]; then
	if [ -h ~/.vimrc ]; then
		echo '====> Uninstall vim'
	else
		echo '====> No vim'
		if [[ "${1}" == "vim" ]]; then
			exit 0
		fi
	fi

	if [ -h ~/.vimrc ]; then
		echo '====> Remove vimrc'
		remove_path ~/.vimrc "vim config file"

		if [[ -f "${config_path}/backups/vimrc.bak" ]]; then
			echo '====> Move vimrc file back'
			if [[ ! -f ~/.vimrc ]]; then
				move_path "${config_path}"/backups/vimrc.bak ~/.vimrc "vim backup"
			fi
		fi

		echo "====> Delete vim plugin"
		remove_path ~/.vim "vim plugin directory" -rf

		echo '====> Uninstall vim config success'
	fi
fi

if [[ "${1}" == "all" || "${1}" == "neovim" ]]; then
	nvim_backup_path=$(first_existing_backup_path "${config_path}/backups/nvim.bak" "${config_path}/backups/nvim_bak")

	if [ -h ~/.config/nvim ]; then
		echo '====> Uninstall neovim'
	else
		echo '====> No neovim'
		if [[ "${1}" == "neovim" ]]; then
			exit 0
		fi
	fi

	if [ -h ~/.config/nvim ]; then
		echo '====> Remove nvim config'
		remove_path ~/.config/nvim "neovim config directory" -r

		if [[ -n "${nvim_backup_path}" && -d "${nvim_backup_path}" ]]; then
			echo '====> Move nvim folder back'
			if [[ ! -d ~/.config/nvim ]]; then
				move_path "${nvim_backup_path}" ~/.config/nvim "neovim backup"
			fi
		fi

		echo "====> Delete neovim plugin"
		remove_path ~/.local/share/nvim "neovim data directory" -rf

		echo '====> Uninstall neovim config success'
	fi
fi

if [[ "${1}" == "all" || "${1}" == "zsh" ]]; then
	if [ -h ~/.zshrc ]; then
		echo '====> Uninstall zsh'
	else
		echo '====> No zsh'
		if [[ "${1}" == "zsh" ]]; then
			exit 0
		fi
	fi

	if [ -h ~/.zshrc ]; then
		echo '====> Remove zshrc'
		remove_path ~/.zshrc "zsh config file"

		if [[ -f "${config_path}/backups/zshrc.bak" ]]; then
			echo '====> Move zshrc file back'
			if [[ ! -f ~/.zshrc ]]; then
				move_path "${config_path}/backups/zshrc.bak" ~/.zshrc "zsh backup"
			fi
		fi

		echo "====> Remove P10k config"
		if [ -h ~/.p10k.zsh ]; then
			remove_path ~/.p10k.zsh "p10k config file"
		fi
		if [[ -f "${config_path}/backups/p10k.zsh.bak" ]]; then
			echo '====> Move P10k config file back'
			if [[ ! -f ~/.p10k.zsh ]]; then
				move_path "${config_path}/backups/p10k.zsh.bak" ~/.p10k.zsh "p10k backup"
			fi
		fi

		echo "====> Remove fzf plugin"
		if [[ -f "${config_path}/backups/fzf.zsh.bak" ]]; then
			move_path "${config_path}/backups/fzf.zsh.bak" ~/.fzf.zsh "fzf backup"
		else
			remove_fzf_custom_config ~/.fzf.zsh
		fi

		echo '====> Uninstall zsh config success'
	fi
fi

if [[ "${1}" == "all" || "${1}" == "ghostty" ]]; then
	ghostty_backup_path=$(first_existing_backup_path "${config_path}/backups/ghostty.bak" "${config_path}/backups/ghostty_bak")

	if [ -h ~/.config/ghostty ]; then
		echo '====> Uninstall ghostty'
	else
		echo '====> No ghostty'
		if [[ "${1}" == "ghostty" ]]; then
			exit 0
		fi
	fi

	if [ -h ~/.config/ghostty ]; then
		echo '====> Remove ghostty config'
		remove_path ~/.config/ghostty "ghostty config directory" -r

		if [[ -n "${ghostty_backup_path}" && -d "${ghostty_backup_path}" ]]; then
			echo '====> Move ghostty folder back'
			if [[ ! -d ~/.config/ghostty ]]; then
				move_path "${ghostty_backup_path}" ~/.config/ghostty "ghostty backup"
			fi
		fi

		echo '====> Uninstall ghostty config success'
	fi
fi
