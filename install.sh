#!/bin/bash

has() {
	command -v "$1" >/dev/null 2>&1
}

fzf_config_start="# Fzf Custom Config"

brew_has() {
	brew list --formula -1 "$1" >/dev/null 2>&1
}

install_on_mac() {
	if ! has brew; then
		echo "====> [ brew ] is not installed, Start To install."
		/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	fi

	if ! brew_has git; then
		echo "----> Install [ git ]."
		brew install git
	fi

	if [[ ${zsh} == 1 ]]; then
		installed=("lua" "zsh" "git" "fzf" "zoxide" "ripgrep" "bat" "trash" "fd" "eza")

		for soft in "${installed[@]}"; do
			if brew_has "${soft}"; then
				echo "====> [ ${soft} ] has been installed."
			else
				echo "----> Install [${soft}]."
				brew install "${soft}"
			fi
		done

		if ! brew list --cask font-hack-nerd-font >/dev/null 2>&1; then
			brew install --cask font-hack-nerd-font
		fi

		if [[ ! -e "${HOME}/.fzf.zsh" ]]; then
			"$(brew --prefix fzf)"/install
		fi
	fi

	if [[ ${tmux} == 1 ]]; then
		if ! brew_has tmux; then
			echo "----> Install [ tmux ]."
			brew install tmux
		fi
	fi

	if [[ ${vim} == 1 ]]; then
		installed=("vim" "im-select" "curl")
		if ! brew tap | grep -q "daipeihust/tap"; then
			brew tap daipeihust/tap
		fi

		for soft in "${installed[@]}"; do
			if brew_has "${soft}"; then
				echo "====> [ ${soft} ] has been installed."
			else
				echo "----> Install [ ${soft} ]."
				brew install "${soft}"
			fi
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
		if ! brew tap | grep -q "daipeihust/tap"; then
			brew tap daipeihust/tap
		fi

		for ((i = 0; i < "${#installed[@]}"; )); do
			if brew_has "${installed[$i + 1]}"; then
				echo "====> [ ${installed[$i + 1]} ] has been installed."
			else
				echo "----> Install [ ${installed[$i + 1]} ]."
				brew install "${installed[$i + 1]}"
			fi
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

if [ ! -d "${HOME}/.config/" ]; then
	mkdir -p "${HOME}/.config"
fi

if [ ! -d "${config_path}/bak" ]; then
	mkdir -p "${config_path}/bak"
fi

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

	if [[ -f ~/.tmux.conf ]]; then
		if [[ -L ~/.tmux.conf && "$(readlink ~/.tmux.conf)" == "${config_path}/tmux/tmux.conf" ]]; then
			echo "====> Tmux config symlink already exists and points to correct location."
		else
			echo "====> Tmux config file [tmux.conf] is exist, backup and delete it."
			mv ~/.tmux.conf "${config_path}/bak/tmux.conf.bak"
		fi
	fi

	echo "====> Create symlink for tmux config"
	ln -sf "${config_path}/tmux/tmux.conf" ~/.tmux.conf
fi

if [[ ${vim} == 1 ]]; then
	# 安装 vim 配置文件
	if [ -f "${HOME}/.vimrc" ]; then
		if [[ -L "${HOME}/.vimrc" && "$(readlink "${HOME}/.vimrc")" == "${config_path}/vi/vim/vimrc" ]]; then
			echo "====> Vim config symlink already exists and points to correct location."
		else
			echo "====> Vim config file the vimrc has exist"
			echo "====> Backup to [ ${config_path}/bak ] and delete it."
			mv "${HOME}/.vimrc" "${config_path}/bak/vimrc.bak"
		fi
	fi

	echo "====> Create symlink for vim config"
	ln -sf "${config_path}/vi/vim/vimrc" "${HOME}/.vimrc"

	# 安装vim插件
	echo "====> Install vim plugins"
	vim +PlugInstall +UpdateRemotePlugins +qa
fi

if [[ ${neovim} == 1 ]]; then
	# 安装 neovim 配置文件
	if [ -d "${HOME}/.config/nvim" ]; then
		if [ -h "${HOME}/.config/nvim" ]; then
			if [[ "$(readlink "${HOME}/.config/nvim")" == "${config_path}/vi/nvim" ]]; then
				echo "====> Neovim config symlink already exists and points to correct location."
			else
				echo "====> Neovim config dir is a link file, only delete it."
				rm -r "${HOME}/.config/nvim"
			fi
		else
			echo "====> Neovim config dir the nvim has exist"
			echo "====> Backup to [ ${config_path}/bak ] and delete it."
			mv "${HOME}/.config/nvim" "${config_path}/bak/nvim_bak"
		fi
	fi

	echo "====> Create symlink for neovim config"
	ln -sf "${config_path}/vi/nvim" "${HOME}/.config/nvim"

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
		fzf_config=$(cat "${config_path}/zsh/fzf.zsh")
		if grep -qxF "${fzf_config_start}" "${HOME}/.fzf.zsh"; then
			echo "====> Custom Fzf config is already insert to [ ${HOME}/.fzf.zsh ]"
		else
			if [[ ! -f "${config_path}/bak/fzf.zsh.bak" ]]; then
				cp "${HOME}/.fzf.zsh" "${config_path}/bak/fzf.zsh.bak"
			fi
			echo "====> Append Custom Fzf config to [ ${HOME}/.fzf.zsh ]"
			echo "${fzf_config}" >>"${HOME}"/.fzf.zsh
		fi
	fi

	# 备份已有的p10k.zsh文件
	if [[ -f "${HOME}/.p10k.zsh" ]]; then
		if [[ -L "${HOME}/.p10k.zsh" && "$(readlink "${HOME}/.p10k.zsh")" == "${config_path}/zsh/p10k.zsh" ]]; then
			echo "====> P10k config symlink already exists and points to correct location."
		else
			echo "====> P10k config file .p10k.zsh is exist."
			echo "====> Backup to [ ${config_path}/bak ] and delete it."
			mv "${HOME}/.p10k.zsh" "${config_path}"/bak/p10k.zsh.bak
		fi
	fi

	echo "====> Create symlink for p10k config"
	ln -sf "${config_path}"/zsh/p10k.zsh ~/.p10k.zsh

	if [[ -f "${HOME}/.zshrc" ]]; then
		if [[ -L "${HOME}/.zshrc" && "$(readlink "${HOME}/.zshrc")" == "${config_path}/zsh/zshrc" ]]; then
			echo "====> Zsh config symlink already exists and points to correct location."
		else
			echo "====> Zsh config file the [ zshrc ] has exist."
			echo "====> Backup to [ ${config_path}/bak ] and delete it."
			mv "${HOME}/.zshrc" "${config_path}/bak/zshrc.bak"
		fi
	fi

	echo "====> Create symlink for zsh config"
	ln -sf "${config_path}"/zsh/zshrc ~/.zshrc

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
	create_ghostty_symlink=1

	if [ -d "${HOME}/.config/ghostty" ]; then
		if [ -h "${HOME}/.config/ghostty" ]; then
			if [[ "$(readlink "${HOME}/.config/ghostty")" == "${config_path}/ghostty" ]]; then
				echo "====> Ghostty config symlink already exists and points to correct location."
				create_ghostty_symlink=0
			else
				echo "====> Ghostty config dir is a link file, only delete it."
				rm -r "${HOME}/.config/ghostty"
			fi
		else
			echo "====> Ghostty config dir has exist"
			echo "====> Backup to [ ${config_path}/bak ] and delete it."
			mv "${HOME}/.config/ghostty" "${config_path}/bak/ghostty_bak"
		fi
	fi

	if [[ ${create_ghostty_symlink} == 1 ]]; then
		echo "====> Create symlink for ghostty config"
		ln -sf "${config_path}/ghostty" "${HOME}/.config/ghostty"
	fi
fi

echo "**** Please change Non-ASCII Font to Hack Nerd Font ****"
