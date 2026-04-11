#!/usr/bin/env bash

fzf_config_start="# Fzf Custom Config"
fzf_config_end="# End Fzf Custom Config"

config_path=$(
	cd "$(dirname "${0}")" || exit
	pwd
)

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
	echo "====> Usage: ./uninstall.sh [all|zsh|tmux|vim|neovim|ghostty]"
	exit 1
fi

if [[ "${1}" == "all" || "${1}" == "tmux" ]]; then
	if [ -h ~/.tmux.conf ]; then
		echo "====> Remove tmux config file"
		rm ~/.tmux.conf >/dev/null 2>&1

		if [[ -f "${config_path}/backups/tmux.conf.bak" ]]; then
			echo "====> Move backup tmux config file"
			if [[ ! -f ~/.tmux.conf ]]; then
				mv "${config_path}/backups/tmux.conf.bak" ~/.tmux.conf
			fi
		fi

		echo "====> Delete tmux plugin"
		rm -rf ~/.tmux >/dev/null 2>&1

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
		rm ~/.vimrc >/dev/null 2>&1

		if [[ -f "${config_path}/backups/vimrc.bak" ]]; then
			echo '====> Move vimrc file back'
			if [[ ! -f ~/.vimrc ]]; then
				mv "${config_path}"/backups/vimrc.bak ~/.vimrc
			fi
		fi

		echo "====> Delete vim plugin"
		rm -rf ~/.vim >/dev/null 2>&1

		echo '====> Uninstall vim config success'
	fi
fi

if [[ "${1}" == "all" || "${1}" == "neovim" ]]; then
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
		rm -r ~/.config/nvim >/dev/null 2>&1

		if [[ -d "${config_path}/backups/nvim_bak" ]]; then
			echo '====> Move nvim folder back'
			if [[ ! -d ~/.config/nvim ]]; then
				mv "${config_path}"/backups/nvim_bak ~/.config/nvim >/dev/null 2>&1
			fi
		fi

		echo "====> Delete neovim plugin"
		rm -rf ~/.local/share/nvim >/dev/null 2>&1

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
		rm ~/.zshrc >/dev/null 2>&1

		if [[ -f "${config_path}/backups/zshrc.bak" ]]; then
			echo '====> Move zshrc file back'
			if [[ ! -f ~/.zshrc ]]; then
				mv "${config_path}/backups/zshrc.bak" ~/.zshrc
			fi
		fi

		echo "====> Remove P10k config"
		if [ -h ~/.p10k.zsh ]; then
			rm ~/.p10k.zsh >/dev/null 2>&1
		fi
		if [[ -f "${config_path}/backups/p10k.zsh.bak" ]]; then
			echo '====> Move P10k config file back'
			if [[ ! -f ~/.p10k.zsh ]]; then
				mv "${config_path}/backups/p10k.zsh.bak" ~/.p10k.zsh
			fi
		fi

		echo "====> Remove fzf plugin"
		if [[ -f "${config_path}/backups/fzf.zsh.bak" ]]; then
			mv "${config_path}/backups/fzf.zsh.bak" ~/.fzf.zsh
		else
			remove_fzf_custom_config ~/.fzf.zsh
		fi

		echo '====> Uninstall zsh config success'
	fi
fi

if [[ "${1}" == "all" || "${1}" == "ghostty" ]]; then
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
		rm -r ~/.config/ghostty >/dev/null 2>&1

		if [[ -d "${config_path}/backups/ghostty_bak" ]]; then
			echo '====> Move ghostty folder back'
			if [[ ! -d ~/.config/ghostty ]]; then
				mv "${config_path}"/backups/ghostty_bak ~/.config/ghostty >/dev/null 2>&1
			fi
		fi

		echo '====> Uninstall ghostty config success'
	fi
fi
