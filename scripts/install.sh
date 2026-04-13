#!/bin/bash

script_dir=$(
	cd "$(dirname "${0}")" || exit
	pwd
)
# shellcheck source=lib/log.sh
source "${script_dir}/lib/log.sh"

repo_root=$(
	cd "${script_dir}/.." || exit
	pwd
)

has() {
	command -v "$1" >/dev/null 2>&1
}

DRY_RUN=0

run_cmd() {
	if [[ ${DRY_RUN} -eq 1 ]]; then
		log_dry "$*"
		return 0
	fi
	"$@"
}

fail() {
	log_error "$1"
	exit 1
}

print_error_banner() {
	local message=$1
	local width=60
	local line

	line=$(printf '%*s' "${width}" '' | tr ' ' '=')
	printf '%s\n' "${line}" >&2
	printf '%*s\n' "$(((${width} + ${#message}) / 2))" "${message}" >&2
	printf '%s\n\n' "${line}" >&2
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
			log_dry "brew install ${formula_name}"
			return 0
		fi
		fail "[ brew ] is not installed."
	fi

	if brew_has "${formula_name}"; then
		log_ok "[ ${formula_name} ] has been installed."
	else
		log_step "Install [ ${formula_name} ]."
		if ! run_cmd brew install "${formula_name}"; then
			fail "Failed to install brew formula [ ${formula_name} ]."
		fi
	fi
}

ensure_brew_cask() {
	local cask_name=$1

	if ! has brew; then
		if [[ ${DRY_RUN} -eq 1 ]]; then
			log_dry "brew install --cask ${cask_name}"
			return 0
		fi
		fail "[ brew ] is not installed."
	fi

	if brew_cask_has "${cask_name}"; then
		log_ok "[ ${cask_name} ] has been installed."
	else
		log_step "Install [ ${cask_name} ]."
		if ! run_cmd brew install --cask "${cask_name}"; then
			fail "Failed to install brew cask [ ${cask_name} ]."
		fi
	fi
}

ensure_brew_tap() {
	local tap_name=$1

	if ! has brew; then
		if [[ ${DRY_RUN} -eq 1 ]]; then
			log_dry "brew tap ${tap_name}"
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
			log_ok "${link_label} symlink already exists and points to correct location."
			return 1
		fi

		if [[ -n "${existing_message}" ]]; then
			log_info "${existing_message}"
		fi
		log_step "Backup to [ ${config_path}/backups ] and delete it."
		if ! run_cmd mv "${target_path}" "${backup_path}"; then
			fail "Failed to back up [ ${target_path} ] to [ ${backup_path} ]."
		fi
	fi

	log_step "${create_message}"
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
		log_step "${link_label} dir is a link file, only delete it."
		if ! run_cmd rm -r "${target_path}"; then
			fail "Failed to remove existing symlinked directory [ ${target_path} ]."
		fi
	elif [[ -d "${target_path}" ]]; then
		if [[ -h "${target_path}" ]]; then
			if [[ "$(readlink "${target_path}")" == "${source_path}" ]]; then
				log_ok "${link_label} symlink already exists and points to correct location."
				return 1
			fi

			log_step "${link_label} dir is a link file, only delete it."
			if ! run_cmd rm -r "${target_path}"; then
				fail "Failed to remove existing symlinked directory [ ${target_path} ]."
			fi
		else
			if [[ -n "${existing_message}" ]]; then
				log_info "${existing_message}"
			fi
			log_step "Backup to [ ${config_path}/backups ] and delete it."
			if ! run_cmd mv "${target_path}" "${backup_path}"; then
				fail "Failed to back up [ ${target_path} ] to [ ${backup_path} ]."
			fi
		fi
	fi

	log_step "${create_message}"
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
		log_dry "update fzf custom block in ${target_file} from ${source_file}"
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
		log_step "[ brew ] is not installed, start to install."
		if [[ ${DRY_RUN} -eq 1 ]]; then
			log_dry "install Homebrew"
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
				log_dry "brew --prefix fzf && <prefix>/install"
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
				log_warn "Please install [ ${installed[i + 1]} ]."
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
				log_warn "Please install [ ${installed[i + 1]} ]."
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
				log_warn "Please install [ ${installed[i + 1]} ]."
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
				log_warn "Please install [ ${installed[i + 1]} ]."
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

config_path="${repo_root}"

root_logged=0
log_root_path_once() {
	if [[ ${root_logged} -eq 0 ]]; then
		log_info "Config file root path is: ${config_path}"
		root_logged=1
	fi
}

print_usage() {
	cat <<'EOF'
Usage:
  ./scripts/install.sh [--dry-run] --apps <brew|all|claude> [args...]
      Install apps.

  ./scripts/install.sh [--dry-run] --conf <all|zsh|tmux|vim|neovim|ghostty>
      Install config symlinks + related setup.

  ./scripts/install.sh [--dry-run] all
      Install all apps + all configs.

  ./scripts/install.sh [--dry-run] --apps brew <brew_mode>
      Install Homebrew formulae/casks from `scripts/brew.sh`.

  ./scripts/install.sh [--dry-run] --apps all
      Install all app installers under `scripts/`.

  ./scripts/install.sh [--dry-run] --apps claude
      Install Claude-related tooling from `scripts/for_claude.sh`.

  ./scripts/install.sh [--dry-run] --conf <all|zsh|tmux|vim|neovim|ghostty>
      Install config symlinks + related setup.

Options:
  --dry-run         Print actions without changing files.
  -h, --help        Show this help.

Arguments:
  brew_mode  all | formula | cask

Examples:
  ./scripts/install.sh --conf zsh
  ./scripts/install.sh --apps brew formula
  ./scripts/install.sh --apps claude
  ./scripts/install.sh all
EOF
}

parse_flags() {
	local arg
	local positional=()
	local has_any_flag=0

	for arg in "$@"; do
		case "${arg}" in
		-h|--help)
			print_usage
			exit 0
			;;
		--apps|--conf)
			positional+=("${arg}")
			;;
		--dry-run)
			DRY_RUN=1
			has_any_flag=1
			;;
		--*)
			print_error_banner "ERROR: Unknown option: ${arg}"
			print_usage
			exit 1
			;;
		*)
			positional+=("${arg}")
			;;
		esac
	done

	set -- "${positional[@]}"
	if [[ ${has_any_flag} -eq 1 ]]; then
		log_info "Options: DRY_RUN=${DRY_RUN}"
	fi
	# shellcheck disable=SC2124
	ARGS=("$@")
}

install_apps() {
	log_root_path_once

	local app=${1:-all}
	local brew_mode=${2:-all}

	case "${app}" in
	all)
		log_section "Install apps: brew (${brew_mode}) + claude"
		"${config_path}/scripts/brew.sh" "${brew_mode}"
		"${config_path}/scripts/for_claude.sh"
		;;
	brew)
		log_section "Install apps: brew (${brew_mode})"
		"${config_path}/scripts/brew.sh" "${brew_mode}"
		;;
	claude)
		log_section "Install apps: claude"
		"${config_path}/scripts/for_claude.sh"
		;;
	*)
		log_error "Unknown apps parameter: ${app}"
		print_usage
		exit 1
		;;
	esac
}

init_log_style
SCRIPT_START_SECONDS=${SECONDS}
parse_flags "$@"
set -- "${ARGS[@]}"

zsh=0 tmux=0 vim=0 neovim=0 ghostty=0
os_name=$(uname -s)
platform_ready=0

orig_primary=${1:-}
primary=${1:-}
secondary=${2:-}

if [[ -z "${primary}" ]]; then
	print_usage
	exit 1
fi

if [[ "${primary}" == "--apps" ]]; then
	shift
	primary="apps"
	secondary=${1:-}
	set -- "apps" "$@"
elif [[ "${primary}" == "--conf" ]]; then
	shift
	primary="conf"
	secondary=${1:-}
	set -- "conf" "$@"
fi

if [[ "${orig_primary}" == "apps" ]]; then
	# legacy positional form: ./scripts/install.sh apps ...
	print_error_banner "ERROR: Use --apps (legacy 'apps' is not supported)"
	print_usage
	exit 1
fi
if [[ "${orig_primary}" == "conf" ]]; then
	# legacy positional form: ./scripts/install.sh conf ...
	print_error_banner "ERROR: Use --conf (legacy 'conf' is not supported)"
	print_usage
	exit 1
fi

if [[ "${primary}" == "all" ]]; then
	if [[ -n "${secondary}" ]]; then
		print_usage
		exit 1
	fi

	if [[ ${os_name} == 'Darwin' ]]; then
		# Ensure brew exists before running app installers on a blank macOS system.
		zsh=1 tmux=1 vim=1 neovim=1 ghostty=1
		log_section "Install platform dependencies (macOS)"
		log_root_path_once
		install_on_mac
		platform_ready=1
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

	if [[ ${os_name} == 'Darwin' ]]; then
		# For apps-only installs, bootstrap brew first on blank macOS.
		log_section "Install platform dependencies (macOS)"
		log_root_path_once
		install_on_mac
		platform_ready=1
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
	log_error "Unknown parameter: ${primary}"
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
	log_error "Unknown parameter: ${1}"
	print_usage
	exit 1
fi

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

if [[ ${platform_ready} -eq 0 ]]; then
	if [[ ${os_name} == 'Darwin' ]]; then
		log_section "Install platform dependencies (macOS)"
		log_root_path_once
		install_on_mac
	elif [[ ${os_name} == 'Linux' ]]; then
		log_section "Install platform dependencies (Linux)"
		log_root_path_once
		install_on_linux
	fi
fi

ensure_dir_exists "${HOME}/.config"
ensure_dir_exists "${config_path}/backups"

#
if [[ ${tmux} == 1 ]]; then
	log_section "Install config: tmux"
	log_info "Install tmux plugins manager (tpm)"
	if [ ! -d ~/.tmux/plugins/tpm ]; then
		tpm_created=0
		if ! run_cmd mkdir -p ~/.tmux/plugins; then
			log_error "Failed to create ~/.tmux/plugins"
			exit 1
		fi
		if [[ ! -e ~/.tmux/plugins/tpm && ! -L ~/.tmux/plugins/tpm ]]; then
			tpm_created=1
		fi
		if ! run_cmd git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm; then
			if [[ ${tpm_created} -eq 1 ]]; then
				run_cmd rm -rf ~/.tmux/plugins/tpm >/dev/null 2>&1 || true
			fi
			log_error "Download tpm failed, install stop"
			exit 1
		fi
		log_ok "Download tpm succeed"
	fi

	ensure_file_symlink \
		~/.tmux.conf \
		"${config_path}/configs/tmux/tmux.conf" \
		"${config_path}/backups/tmux.conf.bak" \
		"Tmux config" \
		"Tmux config file [ tmux.conf ] exists, back up and delete it." \
		"Create symlink for tmux config"
fi

if [[ ${vim} == 1 ]]; then
	log_section "Install config: vim"
	ensure_file_symlink \
		"${HOME}/.vimrc" \
		"${config_path}/configs/vi/vim/vimrc" \
		"${config_path}/backups/vimrc.bak" \
		"Vim config" \
		"Vim config file [ vimrc ] exists, back up and delete it." \
		"Create symlink for vim config"

	# 安装vim插件
	log_info "Install vim plugins"
	if has vim; then
		run_cmd vim +PlugInstall +UpdateRemotePlugins +qa
	else
		log_warn "vim not found, skip plugin install."
	fi
fi

if [[ ${neovim} == 1 ]]; then
	log_section "Install config: neovim"
	ensure_dir_symlink \
		"${HOME}/.config/nvim" \
		"${config_path}/configs/vi/nvim" \
		"${config_path}/backups/nvim.bak" \
		"Neovim config" \
		"Neovim config dir exists, back up and delete it." \
		"Create symlink for neovim config"

	# 安装neovim插件
	log_info "Install nvim plugins"
	if has nvim; then
		if [[ -f "${HOME}/.config/nvim/init.lua" ]]; then
			run_cmd nvim +Lazy +qa
		else
			log_warn "No init.lua found, skip plugin install."
		fi
	else
		log_warn "nvim not found, skip plugin install."
	fi

fi

	if [[ ${zsh} == 1 ]]; then
	log_section "Install config: zsh"
		# golang version manager
	if ! has "g"; then
		log_step "Install [ g ]."
		if [[ ${DRY_RUN} -eq 1 ]]; then
			log_dry "curl -sSL https://raw.githubusercontent.com/voidint/g/master/install.sh | bash"
		else
			if ! curl -sSL https://raw.githubusercontent.com/voidint/g/master/install.sh | bash; then
				log_error "Install g failed"
				exit 1
			fi
		fi
	fi

	# nvm
	if [[ -s "$HOME/.nvm/nvm.sh" ]]; then
		log_ok "NVM already installed, skipping."
	else
		log_step "Installing NVM..."
		if [[ ${DRY_RUN} -eq 1 ]]; then
			log_dry "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash"
		else
			if ! curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash; then
				log_error "Install NVM failed"
				exit 1
			fi
		fi
	fi

	# zinit
	if [[ -f "${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git/zinit.zsh" ]]; then
		log_ok "Zinit already installed, skipping."
	else
		if [[ ${DRY_RUN} -eq 1 ]]; then
			log_dry "install zinit via curl | bash"
		else
			if ! bash -c "$(curl --fail --show-error --silent --location https://raw.githubusercontent.com/zdharma-continuum/zinit/HEAD/scripts/install.sh)"; then
				log_error "Install zinit failed, install stop"
				exit 1
			fi

			if [[ ! -f "${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git/zinit.zsh" ]]; then
				log_error "Zinit was not installed correctly, install stop"
				exit 1
			fi
		fi
	fi

	# 更新的 fzf 配置文件
	if [[ -f "${HOME}/.fzf.zsh" ]]; then
		log_info "Fzf config file [ ${HOME}/.fzf.zsh ] exists, update it."
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
		"P10k config file [ .p10k.zsh ] exists, back up and delete it." \
		"Create symlink for p10k config"

	ensure_file_symlink \
		"${HOME}/.zshrc" \
		"${config_path}/configs/zsh/zshrc" \
		"${config_path}/backups/zshrc.bak" \
		"Zsh config" \
		"Zsh config file [ .zshrc ] exists, back up and delete it." \
		"Create symlink for zsh config"

	log_info "Change to zsh"
	current_shell=$(basename "$SHELL")
	if [[ "${current_shell}" == "zsh" ]]; then
		log_ok "Already using zsh, skipping."
	else
		if ! run_cmd chsh -s /bin/zsh; then
			log_warn "Failed to change shell to zsh. You may need to do it manually."
		fi
	fi
	run_cmd zsh -lc 'source ~/.zshrc'
fi

if [[ ${ghostty} == 1 ]]; then
	log_section "Install config: ghostty"
	ensure_dir_symlink \
		"${HOME}/.config/ghostty" \
		"${config_path}/configs/ghostty" \
		"${config_path}/backups/ghostty.bak" \
		"Ghostty config" \
		"Ghostty config dir exists, back up and delete it." \
		"Create symlink for ghostty config"
fi

log_info "Please change Non-ASCII Font to Hack Nerd Font"
log_ok "Install completed in $((SECONDS - SCRIPT_START_SECONDS))s"
