#!/bin/bash

has() {
	command -v "$1" >/dev/null 2>&1
}

DRY_RUN=0
NO_PLUGINS=0
NO_SHELL_CHANGE=0

run_cmd() {
	if [[ ${DRY_RUN} -eq 1 ]]; then
		echo "DRY-RUN: $*"
		return 0
	fi
	"$@"
}

fail() {
	echo "====> Error: $1"
	exit 1
}

fzf_config_start="# Fzf Custom Config"
fzf_config_end="# End Fzf Custom Config"

brew_has() {
	if ! has brew; then
		return 1
	fi
	brew list --formula -1 "$1" >/dev/null 2>&1
}

brew_cask_has() {
	if ! has brew; then
		return 1
	fi
	brew list --cask "$1" >/dev/null 2>&1
}

ensure_dir_exists() {
	local dir_path=$1

	if [[ ! -d "${dir_path}" ]] && ! run_cmd mkdir -p "${dir_path}"; then
		fail "Failed to create directory [ ${dir_path} ]."
	fi
}

ensure_brew_formula() {
	local formula_name=$1

	if ! has brew; then
		if [[ ${DRY_RUN} -eq 1 ]]; then
			echo "DRY-RUN: brew install ${formula_name}"
			return 0
		fi
		fail "[ brew ] is not installed."
	fi

	if brew_has "${formula_name}"; then
		echo "====> [ ${formula_name} ] has been installed."
	else
		echo "----> Install [ ${formula_name} ]."
		if ! run_cmd brew install "${formula_name}"; then
			fail "Failed to install brew formula [ ${formula_name} ]."
		fi
	fi
}

ensure_brew_cask() {
	local cask_name=$1

	if ! has brew; then
		if [[ ${DRY_RUN} -eq 1 ]]; then
			echo "DRY-RUN: brew install --cask ${cask_name}"
			return 0
		fi
		fail "[ brew ] is not installed."
	fi

	if brew_cask_has "${cask_name}"; then
		echo "====> [ ${cask_name} ] has been installed."
	else
		echo "----> Install [ ${cask_name} ]."
		if ! run_cmd brew install --cask "${cask_name}"; then
			fail "Failed to install brew cask [ ${cask_name} ]."
		fi
	fi
}

ensure_brew_tap() {
	local tap_name=$1

	if ! has brew; then
		if [[ ${DRY_RUN} -eq 1 ]]; then
			echo "DRY-RUN: brew tap ${tap_name}"
			return 0
		fi
		fail "[ brew ] is not installed."
	fi

	if ! brew tap | grep -Fxq "${tap_name}"; then
		if ! run_cmd brew tap "${tap_name}"; then
			fail "Failed to add brew tap [ ${tap_name} ]."
		fi
	fi
}

ensure_file_symlink() {
	local target_path=$1
	local source_path=$2
	local backup_path=$3
	local link_label=$4
	local existing_message=$5
	local create_message=$6

	if [[ ( -e "${target_path}" || -L "${target_path}" ) && ! -d "${target_path}" ]]; then
		if [[ -L "${target_path}" && "$(readlink "${target_path}")" == "${source_path}" ]]; then
			echo "====> ${link_label} symlink already exists and points to correct location."
			return 1
		fi

		if [[ -n "${existing_message}" ]]; then
			echo "${existing_message}"
		fi
		echo "====> Backup to [ ${config_path}/backups ] and delete it."
		if ! run_cmd mv "${target_path}" "${backup_path}"; then
			fail "Failed to back up [ ${target_path} ] to [ ${backup_path} ]."
		fi
	fi

	echo "${create_message}"
	if ! run_cmd ln -sf "${source_path}" "${target_path}"; then
		fail "Failed to create symlink [ ${target_path} ] -> [ ${source_path} ]."
	fi
}

ensure_dir_symlink() {
	local target_path=$1
	local source_path=$2
	local backup_path=$3
	local link_label=$4
	local existing_message=$5
	local create_message=$6

	if [[ -h "${target_path}" && ! -d "${target_path}" ]]; then
		echo "====> ${link_label} dir is a link file, only delete it."
		if ! run_cmd rm -r "${target_path}"; then
			fail "Failed to remove existing symlinked directory [ ${target_path} ]."
		fi
	elif [[ -d "${target_path}" ]]; then
		if [[ -h "${target_path}" ]]; then
			if [[ "$(readlink "${target_path}")" == "${source_path}" ]]; then
				echo "====> ${link_label} symlink already exists and points to correct location."
				return 1
			fi

			echo "====> ${link_label} dir is a link file, only delete it."
			if ! run_cmd rm -r "${target_path}"; then
				fail "Failed to remove existing symlinked directory [ ${target_path} ]."
			fi
		else
			if [[ -n "${existing_message}" ]]; then
				echo "${existing_message}"
			fi
			echo "====> Backup to [ ${config_path}/backups ] and delete it."
			if ! run_cmd mv "${target_path}" "${backup_path}"; then
				fail "Failed to back up [ ${target_path} ] to [ ${backup_path} ]."
			fi
		fi
	fi

	echo "${create_message}"
	if ! run_cmd ln -sf "${source_path}" "${target_path}"; then
		fail "Failed to create symlink [ ${target_path} ] -> [ ${source_path} ]."
	fi
}

upsert_fzf_custom_config() {
	local target_file=$1
	local source_file=$2
	local backup_file=$3
	local tmp_file
	local start_line
	local end_line

	if [[ ! -f "${target_file}" ]]; then
		return
	fi
	if [[ ! -f "${source_file}" ]]; then
		fail "Missing fzf config source file [ ${source_file} ]."
	fi

	if [[ ! -f "${backup_file}" ]]; then
		if ! run_cmd cp "${target_file}" "${backup_file}"; then
			fail "Failed to back up [ ${target_file} ]."
		fi
	fi

	if [[ ${DRY_RUN} -eq 1 ]]; then
		echo "DRY-RUN: update fzf custom block in ${target_file} from ${source_file}"
		return
	fi

	start_line=$(grep -nFx "${fzf_config_start}" "${target_file}" | head -n 1 | cut -d: -f1)
	end_line=$(grep -nFx "${fzf_config_end}" "${target_file}" | tail -n 1 | cut -d: -f1)

	tmp_file=$(mktemp)
	trap 'rm -f "${tmp_file}" >/dev/null 2>&1 || true' RETURN
	if [[ -n "${start_line}" && -n "${end_line}" && ${end_line} -ge ${start_line} ]]; then
		sed "${start_line},${end_line}d" "${target_file}" >"${tmp_file}"
	elif [[ -n "${start_line}" ]]; then
		# Start marker exists but end marker missing/corrupted: remove start..EOF to avoid duplicates.
		sed "${start_line},\$d" "${target_file}" >"${tmp_file}"
	elif [[ -n "${end_line}" ]]; then
		# End marker exists without start marker: remove only the marker line (least destructive).
		sed "${end_line}d" "${target_file}" >"${tmp_file}"
	else
		cat "${target_file}" >"${tmp_file}"
	fi

	{
		cat "${tmp_file}"
		echo ""
		cat "${source_file}"
	} >"${target_file}"
}

install_on_mac() {
	if ! has brew; then
		echo "====> [ brew ] is not installed, Start To install."
		if [[ ${DRY_RUN} -eq 1 ]]; then
			echo "DRY-RUN: install Homebrew"
		elif ! /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
			fail "Failed to install Homebrew."
		fi
	fi

	ensure_brew_formula git

	if [[ ${zsh} == 1 ]]; then
		installed=("lua" "zsh" "git" "fzf" "zoxide" "ripgrep" "bat" "trash" "fd" "eza")

		for soft in "${installed[@]}"; do
			ensure_brew_formula "${soft}"
		done

		ensure_brew_cask font-hack-nerd-font

		if [[ ! -e "${HOME}/.fzf.zsh" ]]; then
			if has brew; then
				run_cmd "$(brew --prefix fzf)"/install
			elif [[ ${DRY_RUN} -eq 1 ]]; then
				echo "DRY-RUN: brew --prefix fzf && <prefix>/install"
			else
				fail "[ brew ] is not installed."
			fi
		fi
	fi

	if [[ ${tmux} == 1 ]]; then
		ensure_brew_formula tmux
	fi

	if [[ ${vim} == 1 ]]; then
		installed=("vim" "im-select" "curl")
		ensure_brew_tap daipeihust/tap

		for soft in "${installed[@]}"; do
			ensure_brew_formula "${soft}"
		done
	fi

	if [[ ${neovim} == 1 ]]; then
		installed=(
			"nvim" "neovim"
			"lua" "lua"
			"luarocks" "luarocks"
			"node" "node"
			"sqlite" "sqlite"
			"im-select" "im-select"
			"lazygit" "lazygit"
			"go" "go"
			"wget" "wget"
			"gnu-sed" "gnu-sed"
		)
		ensure_brew_tap daipeihust/tap

		for ((i = 0; i < "${#installed[@]}"; )); do
			ensure_brew_formula "${installed[$i + 1]}"
			i=$((i + 2))
		done
	fi
}

install_on_linux() {
	need_exit=0
	if [[ ${zsh} == 1 ]]; then
		installed=(
			"git" "git"
			"zsh" "zsh"
			"lua" "lua"
			"rg" "ripgrep"
			"batcat" "bat"
			"fdfind" "fd-find"
			"zoxide" "zoxide"
		)

		for ((i = 0; i < "${#installed[@]}"; )); do
			if ! has "${installed[i]}"; then
				echo "----> Please Install [ ${installed[i + 1]} ]."
				need_exit=1
			fi
			((i += 2))
		done
	fi

	if [[ ${tmux} == 1 ]]; then
		installed=(
			"git" "git"
			"tmux" "tmux"
		)

		for ((i = 0; i < "${#installed[@]}"; )); do
			if ! has "${installed[i]}"; then
				echo "----> Please Install [ ${installed[i + 1]} ]."
				need_exit=1
			fi
			((i += 2))
		done
	fi

	if [[ ${vim} == 1 ]]; then
		installed=(
			"git" "git"
			"vim" "vim"
		)

		for ((i = 0; i < "${#installed[@]}"; )); do
			if ! has "${installed[i]}"; then
				echo "----> Please Install [ ${installed[i + 1]} ]."
				need_exit=1
			fi
			((i += 2))
		done
	fi

	if [[ ${neovim} == 1 ]]; then
		installed=(
			"git" "git"
			"nvim" "neovim"
			"lua" "lua"
			"luarocks" "luarocks"
			"node" "node"
			"sqlite" "sqlite"

		)

		for ((i = 0; i < "${#installed[@]}"; )); do
			if ! has "${installed[i]}"; then
				echo "----> Please Install [ ${installed[i + 1]} ]."
				need_exit=1
			fi
			((i += 2))
		done
	fi
	if [[ ${need_exit} == 1 ]]; then
		exit 1
	fi
}

# ------------------------------

config_path=$(
	cd "$(dirname "${0}")" || exit
	pwd
)

root_logged=0
log_root_path_once() {
	if [[ ${root_logged} -eq 0 ]]; then
		echo "====> Config file root path is: ${config_path}"
		root_logged=1
	fi
}

print_usage() {
	cat <<'EOF'
Usage:
  ./install.sh [--dry-run] [--no-plugins] [--no-shell-change] all
      Install all apps + all configs.

  ./install.sh [--dry-run] [--no-plugins] [--no-shell-change] apps brew <brew_mode>
      Install Homebrew formulae/casks from `apps/brew.sh`.

  ./install.sh [--dry-run] [--no-plugins] [--no-shell-change] apps all
      Install all scripts under `apps/`.

  ./install.sh [--dry-run] [--no-plugins] [--no-shell-change] apps claude
      Install Claude-related tooling from `apps/for_claude.sh`.

  ./install.sh [--dry-run] [--no-plugins] [--no-shell-change] conf <all|zsh|tmux|vim|neovim|ghostty>
      Install config symlinks + related setup.

Options:
  --dry-run         Print actions without changing files.
  --no-plugins      Skip tmux/vim/nvim plugin installation steps.
  --no-shell-change Skip `chsh` and `zsh -lc 'source ~/.zshrc'`.

Compatibility:
  ./install.sh all
      Install all apps + all configs.

  ./install.sh apps brew <brew_mode>
      Install Homebrew formulae/casks from `apps/brew.sh`.

  ./install.sh apps all
      Install all scripts under `apps/`.

  ./install.sh apps claude
      Install Claude-related tooling from `apps/for_claude.sh`.

  ./install.sh conf <all|zsh|tmux|vim|neovim|ghostty>
      Install config symlinks + related setup.

Options:
  brew_mode  all | formula | cask

Examples:
  ./install.sh conf zsh
  ./install.sh apps brew formula
  ./install.sh apps claude
  ./install.sh all
EOF
}

parse_flags() {
	local arg
	local positional=()

	for arg in "$@"; do
		case "${arg}" in
		--dry-run)
			DRY_RUN=1
			;;
		--no-plugins)
			NO_PLUGINS=1
			;;
		--no-shell-change)
			NO_SHELL_CHANGE=1
			;;
		--*)
			echo "====> Error: Unknown option: ${arg}"
			print_usage
			exit 1
			;;
		*)
			positional+=("${arg}")
			;;
		esac
	done

	set -- "${positional[@]}"
	echo "====> Options: DRY_RUN=${DRY_RUN} NO_PLUGINS=${NO_PLUGINS} NO_SHELL_CHANGE=${NO_SHELL_CHANGE}"
	# shellcheck disable=SC2124
	ARGS=("$@")
}

install_apps() {
	log_root_path_once

	local app=${1:-all}
	local brew_mode=${2:-all}

	case "${app}" in
	all)
		"${config_path}/apps/brew.sh" "${brew_mode}"
		"${config_path}/apps/for_claude.sh"
		;;
	brew)
		"${config_path}/apps/brew.sh" "${brew_mode}"
		;;
	claude)
		"${config_path}/apps/for_claude.sh"
		;;
	*)
		echo "====> Error: Unknown apps parameter: ${app}"
		print_usage
		exit 1
		;;
	esac
}

parse_flags "$@"
set -- "${ARGS[@]}"

primary=${1:-}
secondary=${2:-}

if [[ -z "${primary}" ]]; then
	print_usage
	exit 1
fi

if [[ "${primary}" == "all" ]]; then
	if [[ -n "${secondary}" ]]; then
		print_usage
		exit 1
	fi

	install_apps "brew" "all"
	install_apps "claude"

	# continue with conf all
	set -- conf all
	primary=${1}
	secondary=${2}
fi

if [[ "${primary}" == "apps" ]]; then
	if [[ -z "${secondary}" ]]; then
		print_usage
		exit 0
	fi

	case "${secondary}" in
	brew)
		if [[ -z "${3:-}" ]]; then
			print_usage
			exit 1
		fi
		install_apps "brew" "${3}"
		;;
	all)
		if [[ -n "${3:-}" ]]; then
			print_usage
			exit 1
		fi
		install_apps "all" "all"
		;;
	claude)
		install_apps "${secondary}"
		;;
	*)
		install_apps "${secondary}" "${3:-all}"
		;;
	esac
	exit 0
fi

if [[ "${primary}" == "conf" ]]; then
	if [[ -z "${secondary}" ]]; then
		print_usage
		exit 0
	fi
	shift
else
	echo "====> Error: Unknown parameter: ${primary}"
	print_usage
	exit 1
fi

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

zsh=0 tmux=0 vim=0 neovim=0 ghostty=0

case ${1} in
all)
	zsh=1 tmux=1 vim=1 neovim=1 ghostty=1
	;;
zsh)
	zsh=1
	;;
tmux)
	tmux=1
	;;
vim)
	vim=1
	;;
neovim)
	neovim=1
	;;
ghostty)
	ghostty=1
	;;
esac

os_name=$(uname -s)
if [[ ${os_name} == 'Darwin' ]]; then
	log_root_path_once
	install_on_mac
elif [[ ${os_name} == 'Linux' ]]; then
	log_root_path_once
	install_on_linux
fi

ensure_dir_exists "${HOME}/.config"
ensure_dir_exists "${config_path}/backups"

#
if [[ ${tmux} == 1 ]]; then
	echo "====> Install tmux plugins manage plugin tpm"
	if [ ! -d ~/.tmux/plugins/tpm ]; then
		if [[ ${NO_PLUGINS} -eq 1 ]]; then
			echo "====> Skip tmux plugin install (NO_PLUGINS=1)"
		else
			tpm_created=0
			if ! run_cmd mkdir -p ~/.tmux/plugins; then
				echo "====> Error: Failed to create ~/.tmux/plugins"
				exit 1
			fi
			if [[ ! -e ~/.tmux/plugins/tpm && ! -L ~/.tmux/plugins/tpm ]]; then
				tpm_created=1
			fi
			if ! run_cmd git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm; then
				if [[ ${tpm_created} -eq 1 ]]; then
					run_cmd rm -rf ~/.tmux/plugins/tpm >/dev/null 2>&1 || true
				fi
				echo "====> Error: Download tpm failed, install stop"
				exit 1
			fi
			echo "====> Download tpm Succeed"
		fi
	fi

	ensure_file_symlink \
		~/.tmux.conf \
		"${config_path}/configs/tmux/tmux.conf" \
		"${config_path}/backups/tmux.conf.bak" \
		"Tmux config" \
		"====> Tmux config file [tmux.conf] is exist, backup and delete it." \
		"====> Create symlink for tmux config"
fi

if [[ ${vim} == 1 ]]; then
	ensure_file_symlink \
		"${HOME}/.vimrc" \
		"${config_path}/configs/vi/vim/vimrc" \
		"${config_path}/backups/vimrc.bak" \
		"Vim config" \
		"====> Vim config file the vimrc has exist" \
		"====> Create symlink for vim config"

	# 安装vim插件
	echo "====> Install vim plugins"
	if [[ ${NO_PLUGINS} -eq 1 ]]; then
		echo "====> Skip vim plugin install (NO_PLUGINS=1)"
	elif has vim; then
		run_cmd vim +PlugInstall +UpdateRemotePlugins +qa
	else
		echo "====> Warning: vim not found, skip plugin install."
	fi
fi

if [[ ${neovim} == 1 ]]; then
	ensure_dir_symlink \
		"${HOME}/.config/nvim" \
		"${config_path}/configs/vi/nvim" \
		"${config_path}/backups/nvim.bak" \
		"Neovim config" \
		"====> Neovim config dir the nvim has exist" \
		"====> Create symlink for neovim config"

	# 安装neovim插件
	echo "====> Install nvim plugins"
	if [[ ${NO_PLUGINS} -eq 1 ]]; then
		echo "====> Skip nvim plugin install (NO_PLUGINS=1)"
	elif has nvim; then
		run_cmd nvim +Lazy +qa
	else
		echo "====> Warning: nvim not found, skip plugin install."
	fi

fi

	if [[ ${zsh} == 1 ]]; then
		# golang version manager
	if ! has "g"; then
		echo "----> Install [ g ]."
		if [[ ${DRY_RUN} -eq 1 ]]; then
			echo "DRY-RUN: curl -sSL https://raw.githubusercontent.com/voidint/g/master/install.sh | bash"
		else
			if ! curl -sSL https://raw.githubusercontent.com/voidint/g/master/install.sh | bash; then
				echo "====> Error: Install g failed"
				exit 1
			fi
		fi
	fi

	# nvm
	if [[ -s "$HOME/.nvm/nvm.sh" ]]; then
		echo "====> NVM already installed, skipping."
	else
		echo "====> Installing NVM..."
		if [[ ${DRY_RUN} -eq 1 ]]; then
			echo "DRY-RUN: curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash"
		else
			if ! curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash; then
				echo "====> Error: Install NVM failed"
				exit 1
			fi
		fi
	fi

	# zinit
	if [[ -f "${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git/zinit.zsh" ]]; then
		echo "====> Zinit already installed, skipping."
	else
		if [[ ${DRY_RUN} -eq 1 ]]; then
			echo "DRY-RUN: install zinit via curl | bash"
		else
			if ! bash -c "$(curl --fail --show-error --silent --location https://raw.githubusercontent.com/zdharma-continuum/zinit/HEAD/scripts/install.sh)"; then
				echo "====> Error: Install zinit failed, install stop"
				exit 1
			fi

			if [[ ! -f "${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git/zinit.zsh" ]]; then
				echo "====> Error: Zinit was not installed correctly, install stop"
				exit 1
			fi
		fi
	fi

	# 更新的 fzf 配置文件
	if [[ -f "${HOME}/.fzf.zsh" ]]; then
		echo "====> Fzf config file [ ${HOME}/.fzf.zsh ] exist, update it."
		upsert_fzf_custom_config \
			"${HOME}/.fzf.zsh" \
			"${config_path}/configs/zsh/fzf.zsh" \
			"${config_path}/backups/fzf.zsh.bak"
	fi

	ensure_file_symlink \
		"${HOME}/.p10k.zsh" \
		"${config_path}/configs/zsh/p10k.zsh" \
		"${config_path}/backups/p10k.zsh.bak" \
		"P10k config" \
		"====> P10k config file .p10k.zsh is exist." \
		"====> Create symlink for p10k config"

	ensure_file_symlink \
		"${HOME}/.zshrc" \
		"${config_path}/configs/zsh/zshrc" \
		"${config_path}/backups/zshrc.bak" \
		"Zsh config" \
		"====> Zsh config file the [ zshrc ] has exist." \
		"====> Create symlink for zsh config"

	echo "====> Change to zsh"
	current_shell=$(basename "$SHELL")
	if [[ "${current_shell}" == "zsh" ]]; then
		echo "====> Already using zsh, skipping."
	else
		if [[ ${NO_SHELL_CHANGE} -eq 1 ]]; then
			echo "====> Skip shell change (NO_SHELL_CHANGE=1)"
		else
			if ! run_cmd chsh -s /bin/zsh; then
				echo "====> Warning: Failed to change shell to zsh. You may need to do it manually."
			fi
		fi
	fi
	if [[ ${NO_SHELL_CHANGE} -eq 1 ]]; then
		echo "====> Skip sourcing zshrc (NO_SHELL_CHANGE=1)"
	else
		run_cmd zsh -lc 'source ~/.zshrc'
	fi
fi

if [[ ${ghostty} == 1 ]]; then
	ensure_dir_symlink \
		"${HOME}/.config/ghostty" \
		"${config_path}/configs/ghostty" \
		"${config_path}/backups/ghostty.bak" \
		"Ghostty config" \
		"====> Ghostty config dir has exist" \
		"====> Create symlink for ghostty config"
fi

echo "**** Please change Non-ASCII Font to Hack Nerd Font ****"
