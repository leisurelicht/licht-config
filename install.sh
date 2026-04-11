#!/bin/bash

has() {
	command -v "$1" >/dev/null 2>&1
}

fail() {
	echo "====> Error: $1"
	exit 1
}

fzf_config_start="# Fzf Custom Config"

brew_has() {
	brew list --formula -1 "$1" >/dev/null 2>&1
}

brew_cask_has() {
	brew list --cask "$1" >/dev/null 2>&1
}

ensure_dir_exists() {
	local dir_path=$1

	if [[ ! -d "${dir_path}" ]] && ! mkdir -p "${dir_path}"; then
		fail "Failed to create directory [ ${dir_path} ]."
	fi
}

ensure_brew_formula() {
	local formula_name=$1

	if brew_has "${formula_name}"; then
		echo "====> [ ${formula_name} ] has been installed."
	else
		echo "----> Install [ ${formula_name} ]."
		if ! brew install "${formula_name}"; then
			fail "Failed to install brew formula [ ${formula_name} ]."
		fi
	fi
}

ensure_brew_cask() {
	local cask_name=$1

	if brew_cask_has "${cask_name}"; then
		echo "====> [ ${cask_name} ] has been installed."
	else
		echo "----> Install [ ${cask_name} ]."
		if ! brew install --cask "${cask_name}"; then
			fail "Failed to install brew cask [ ${cask_name} ]."
		fi
	fi
}

ensure_brew_tap() {
	local tap_name=$1

	if ! brew tap | grep -q "^${tap_name}$"; then
		if ! brew tap "${tap_name}"; then
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

	if [[ -f "${target_path}" ]]; then
		if [[ -L "${target_path}" && "$(readlink "${target_path}")" == "${source_path}" ]]; then
			echo "====> ${link_label} symlink already exists and points to correct location."
			return 1
		fi

		if [[ -n "${existing_message}" ]]; then
			echo "${existing_message}"
		fi
		echo "====> Backup to [ ${config_path}/backups ] and delete it."
		if ! mv "${target_path}" "${backup_path}"; then
			fail "Failed to back up [ ${target_path} ] to [ ${backup_path} ]."
		fi
	fi

	echo "${create_message}"
	if ! ln -sf "${source_path}" "${target_path}"; then
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

	if [[ -d "${target_path}" ]]; then
		if [[ -h "${target_path}" ]]; then
			if [[ "$(readlink "${target_path}")" == "${source_path}" ]]; then
				echo "====> ${link_label} symlink already exists and points to correct location."
				return 1
			fi

			echo "====> ${link_label} dir is a link file, only delete it."
			if ! rm -r "${target_path}"; then
				fail "Failed to remove existing symlinked directory [ ${target_path} ]."
			fi
		else
			if [[ -n "${existing_message}" ]]; then
				echo "${existing_message}"
			fi
			echo "====> Backup to [ ${config_path}/backups ] and delete it."
			if ! mv "${target_path}" "${backup_path}"; then
				fail "Failed to back up [ ${target_path} ] to [ ${backup_path} ]."
			fi
		fi
	fi

	echo "${create_message}"
	if ! ln -sf "${source_path}" "${target_path}"; then
		fail "Failed to create symlink [ ${target_path} ] -> [ ${source_path} ]."
	fi
}

install_on_mac() {
	if ! has brew; then
		echo "====> [ brew ] is not installed, Start To install."
		if ! /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
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
			"$(brew --prefix fzf)"/install
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

echo "====> Config file root path is: ${config_path}"

commands=("all" "zsh" "tmux" "vim" "neovim" "ghostty")
command_found=0
for command in "${commands[@]}"; do
	if [[ "${command}" == "${1}" ]]; then
		command_found=1
		break
	fi
done

# 判断第一个命令行参数是否是 commands 中的一个
if [[ ${command_found} -ne 1 ]]; then
	echo "====> Error: Unknown parameter: ${1}"
	echo "====> Usage: ./install.sh [all|zsh|tmux|vim|neovim|ghostty]"
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

if [[ $(uname -s) == 'Darwin' ]]; then
	install_on_mac
elif [[ $(uname -s) == 'Linux' ]]; then
	install_on_linux
fi

ensure_dir_exists "${HOME}/.config"
ensure_dir_exists "${config_path}/backups"

#
if [[ ${tmux} == 1 ]]; then
	echo "====> Install tmux plugins manage plugin tpm"
	if [ ! -d ~/.tmux/plugins/tpm ]; then
		if ! git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm; then
			rm -r ~/.tmux/plugins/tpm >/dev/null 2>&1
			echo "====> Error: Download tpm failed, install stop"
			exit 1
		else
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
	vim +PlugInstall +UpdateRemotePlugins +qa
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
	nvim +Lazy +qa

fi

if [[ ${zsh} == 1 ]]; then
	# golang version manager
	if ! has "g"; then
		echo "----> Install [ g ]."
		if ! curl -sSL https://raw.githubusercontent.com/voidint/g/master/install.sh | bash; then
			echo "====> Error: Install g failed"
			exit 1
		fi
	fi

	# nvm
	if [[ -s "$HOME/.nvm/nvm.sh" ]]; then
		echo "====> NVM already installed, skipping."
	else
		echo "====> Installing NVM..."
		if ! curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash; then
			echo "====> Error: Install NVM failed"
			exit 1
		fi
	fi

	# zinit
	if [[ -f "${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git/zinit.zsh" ]]; then
		echo "====> Zinit already installed, skipping."
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

	# 更新的 fzf 配置文件
	if [[ -f "${HOME}/.fzf.zsh" ]]; then
		echo "====> Fzf config file [ ${HOME}/.fzf.zsh ] exist, update it."
		fzf_config=$(cat "${config_path}/configs/zsh/fzf.zsh")
		if grep -qxF "${fzf_config_start}" "${HOME}/.fzf.zsh"; then
			echo "====> Custom Fzf config is already insert to [ ${HOME}/.fzf.zsh ]"
		else
			if [[ ! -f "${config_path}/backups/fzf.zsh.bak" ]]; then
				if ! cp "${HOME}/.fzf.zsh" "${config_path}/backups/fzf.zsh.bak"; then
					fail "Failed to back up [ ${HOME}/.fzf.zsh ]."
				fi
			fi
			echo "====> Append Custom Fzf config to [ ${HOME}/.fzf.zsh ]"
			if ! echo "${fzf_config}" >>"${HOME}"/.fzf.zsh; then
				fail "Failed to update [ ${HOME}/.fzf.zsh ]."
			fi
		fi
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
		if ! chsh -s /bin/zsh; then
			echo "====> Warning: Failed to change shell to zsh. You may need to do it manually."
		fi
	fi
	zsh -lc 'source ~/.zshrc'
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
