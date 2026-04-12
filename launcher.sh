#!/usr/bin/env bash

set -u

script_dir=$(
	cd "$(dirname "${0}")" || exit
	pwd
)

install_script="${script_dir}/install.sh"
uninstall_script="${script_dir}/uninstall.sh"

if [[ ! -x "${install_script}" || ! -x "${uninstall_script}" ]]; then
	echo "Missing install.sh or uninstall.sh in ${script_dir}" >&2
	exit 1
fi

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
	cat <<'USAGE'
Usage:
  ./launcher.sh

Interactive TUI launcher for install/uninstall workflows.
Keys:
  Up/Down or j/k: move
  Space: toggle (multi-select)
  Left: back
  Right: next
  Enter: continue/confirm
  q: quit
USAGE
	exit 0
fi

if [[ ! -t 0 || ! -t 1 ]]; then
	echo "launcher.sh requires an interactive terminal." >&2
	echo "Use install.sh/uninstall.sh directly in non-interactive mode." >&2
	exit 1
fi

C_RESET='\033[0m'
C_BG='\033[48;5;234m'
C_TITLE='\033[38;5;81m'
C_ACCENT='\033[38;5;159m'
C_WARN='\033[38;5;214m'
C_ERROR='\033[38;5;203m'
C_DIM='\033[38;5;244m'
C_OK='\033[38;5;120m'

STEP=1
ACTION=""
SCOPE=""
BREW_MODE="all"
APP_BREW=1
APP_CLAUDE=0
CFG_ZSH=1
CFG_TMUX=1
CFG_VIM=1
CFG_NEOVIM=1
CFG_GHOSTTY=1

MENU_RESULT=0
MENU_BACK=0
MENU_QUIT=0
OS_DISPLAY=""

action_label() {
	if [[ "${ACTION}" == "uninstall" ]]; then
		printf '%s' "Uninstall"
	else
		printf '%s' "Install"
	fi
}

read_key() {
	local key rest
	IFS= read -rsn1 key || return 1
	if [[ "${key}" == $'\x1b' ]]; then
		IFS= read -rsn2 rest || true
		key+="${rest}"
	fi
	printf '%s' "${key}"
}

clear_screen() {
	printf '\033c'
}

detect_os_display() {
	local os_name
	local os_kernel

	os_name=$(uname -s 2>/dev/null || echo "Unknown")
	os_kernel=$(uname -r 2>/dev/null || echo "")

	case "${os_name}" in
	Darwin)
		if command -v sw_vers >/dev/null 2>&1; then
			printf 'macOS %s (Darwin %s)' "$(sw_vers -productVersion 2>/dev/null)" "${os_kernel}"
		else
			printf 'macOS (Darwin %s)' "${os_kernel}"
		fi
		;;
	Linux)
		printf 'Linux %s' "${os_kernel}"
		;;
	*)
		printf '%s %s' "${os_name}" "${os_kernel}"
		;;
	esac
}

print_banner() {
	printf "%b" "${C_BG}"
	cat <<'BANNER'

  ██╗     ██╗ ██████╗██╗  ██╗████████╗      ██████╗ ██████╗ ███╗   ██╗███████╗
  ██║     ██║██╔════╝██║  ██║╚══██╔══╝     ██╔════╝██╔═══██╗████╗  ██║██╔════╝
  ██║     ██║██║     ███████║   ██║        ██║     ██║   ██║██╔██╗ ██║█████╗
  ██║     ██║██║     ██╔══██║   ██║        ██║     ██║   ██║██║╚██╗██║██╔══╝
  ███████╗██║╚██████╗██║  ██║   ██║        ╚██████╗╚██████╔╝██║ ╚████║██║
  ╚══════╝╚═╝ ╚═════╝╚═╝  ╚═╝   ╚═╝         ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝
BANNER
	printf "%b\n" "${C_RESET}"
}

print_workflow() {
	local current_step=$1
	local labels=("Action" "Scope" "Components" "Preview" "Confirm" "Run")
	local i bullet color

	printf "  Workflow\n"
	for ((i = 1; i <= 6; i++)); do
		bullet="○"
		color="${C_DIM}"
		if [[ ${i} -lt ${current_step} ]]; then
			bullet="●"
			color="${C_OK}"
		elif [[ ${i} -eq ${current_step} ]]; then
			bullet="●"
			color="${C_ACCENT}"
		fi
		printf "  %b%s%b %d. %s\n" "${color}" "${bullet}" "${C_RESET}" "${i}" "${labels[$((i - 1))]}"
	done
	printf "\n"
}

render_progress() {
	local done=$1
	local total=$2
	local width=34
	local filled=0
	local empty=0
	local percent=0
	local bar_filled bar_empty

	if [[ ${total} -gt 0 ]]; then
		filled=$((done * width / total))
		percent=$((done * 100 / total))
	fi
	empty=$((width - filled))
	bar_filled=$(printf '%*s' "${filled}" '' | tr ' ' '█')
	bar_empty=$(printf '%*s' "${empty}" '' | tr ' ' '░')
	printf "  %b[%s%s]%b %3d%% (%d/%d)\n" "${C_ACCENT}" "${bar_filled}" "${bar_empty}" "${C_RESET}" "${percent}" "${done}" "${total}"
}

print_frame_header() {
	local title=$1
	local subtitle=$2
	local current_step=$3
	local mode_color="${C_ACCENT}"
	local os_line_plain
	local content_width=78
	local pad=0

	if [[ "${ACTION}" == "uninstall" ]]; then
		mode_color="${C_WARN}"
	fi
	os_line_plain="OS: ${OS_DISPLAY}"
	if [[ ${#os_line_plain} -lt ${content_width} ]]; then
		pad=$(((content_width - ${#os_line_plain}) / 2))
	fi

	printf "%b╭──────────────────────────────────────────────────────────────────────────────╮%b\n" "${C_DIM}" "${C_RESET}"
	printf "%b│%*s%-*s│%b\n" "${C_DIM}" "${pad}" "" "$((content_width - pad))" "${os_line_plain}" "${C_RESET}"
	printf "%b├──────────────────────────────────────────────────────────────────────────────┤%b\n" "${C_DIM}" "${C_RESET}"
	printf "  %b%s%b · %s\n\n" "${mode_color}" "${title}" "${C_RESET}" "${subtitle}"
	print_workflow "${current_step}"
}

print_frame_footer() {
	local help=$1
	local content_width=76
	local pad=0
	if [[ ${#help} -lt ${content_width} ]]; then
		pad=$(((content_width - ${#help}) / 2))
	fi
	printf "\n  %*s%b%s%b\n" "${pad}" "" "${C_DIM}" "${help}" "${C_RESET}"
	printf "%b╰──────────────────────────────────────────────────────────────────────────────╯%b\n" "${C_DIM}" "${C_RESET}"
}

menu_single() {
	local title=$1
	local subtitle=$2
	local step_no=$3
	shift 3
	local options=("$@")
	local idx=0
	local i key

	MENU_BACK=0
	MENU_QUIT=0

	while true; do
		clear_screen
		print_banner
		print_frame_header "${title}" "${subtitle}" "${step_no}"

		for ((i = 0; i < ${#options[@]}; i++)); do
			if [[ ${i} -eq ${idx} ]]; then
				printf "  %b>%b %b%s%b\n" "${C_ACCENT}" "${C_RESET}" "${C_TITLE}" "${options[i]}" "${C_RESET}"
			else
				printf "    %s\n" "${options[i]}"
			fi
		done

		print_frame_footer "[←] Back  [→] Next  [↑/↓] Navigate  [Enter] Confirm  [Q] Quit"
		key=$(read_key) || continue
		case "${key}" in
		$'\x1b[A'|k)
			idx=$((idx - 1))
			if [[ ${idx} -lt 0 ]]; then idx=$((${#options[@]} - 1)); fi
			;;
		$'\x1b[B'|j)
			idx=$((idx + 1))
			if [[ ${idx} -ge ${#options[@]} ]]; then idx=0; fi
			;;
		""|$'\n'|$'\r')
			MENU_RESULT=${idx}
			return 0
			;;
		$'\x1b[D')
			MENU_BACK=1
			return 0
			;;
		$'\x1b[C')
			MENU_RESULT=${idx}
			return 0
			;;
		q|Q)
			MENU_QUIT=1
			return 0
			;;
		esac
	done
}

menu_apps_multi() {
	local idx=0
	local options=("brew" "claude")
	local desc=("install packages/casks" "install claude helper")
	local key i checked

	MENU_BACK=0
	MENU_QUIT=0

	while true; do
		clear_screen
		print_banner
		print_frame_header "$(action_label) 3/6" "Select Apps" 3

		for ((i = 0; i < ${#options[@]}; i++)); do
			checked="[ ]"
			if [[ ${i} -eq 0 && ${APP_BREW} -eq 1 ]]; then checked="[x]"; fi
			if [[ ${i} -eq 1 && ${APP_CLAUDE} -eq 1 ]]; then checked="[x]"; fi
			if [[ ${idx} -eq ${i} ]]; then
				printf "  %b>%b %s %b%-8s%b %s\n" "${C_ACCENT}" "${C_RESET}" "${checked}" "${C_TITLE}" "${options[i]}" "${C_RESET}" "${desc[i]}"
			else
				printf "    %s %-8s %s\n" "${checked}" "${options[i]}" "${desc[i]}"
			fi
		done

		if [[ ${APP_BREW} -eq 1 ]]; then
			printf "\n  Brew mode: %b%s%b\n" "${C_ACCENT}" "${BREW_MODE}" "${C_RESET}"
			printf "  Press %b%s%b to switch brew mode\n" "${C_TITLE}" "b" "${C_RESET}"
		fi

		print_frame_footer "[←] Back  [→] Next  [↑/↓] Navigate  [Space] Toggle  [B] Brew mode"
		key=$(read_key) || continue
		case "${key}" in
		$'\x1b[A'|k)
			idx=$((idx - 1)); if [[ ${idx} -lt 0 ]]; then idx=$((${#options[@]} - 1)); fi
			;;
		$'\x1b[B'|j)
			idx=$((idx + 1)); if [[ ${idx} -ge ${#options[@]} ]]; then idx=0; fi
			;;
		" ")
			if [[ ${idx} -eq 0 ]]; then
				if [[ ${APP_BREW} -eq 1 ]]; then APP_BREW=0; else APP_BREW=1; fi
			else
				if [[ ${APP_CLAUDE} -eq 1 ]]; then APP_CLAUDE=0; else APP_CLAUDE=1; fi
			fi
			;;
		b|B)
			if [[ ${APP_BREW} -eq 1 ]]; then
				if [[ "${BREW_MODE}" == "all" ]]; then
					BREW_MODE="formula"
				elif [[ "${BREW_MODE}" == "formula" ]]; then
					BREW_MODE="cask"
				else
					BREW_MODE="all"
				fi
			fi
			;;
		""|$'\n'|$'\r')
			if [[ ${APP_BREW} -eq 0 && ${APP_CLAUDE} -eq 0 ]]; then
				continue
			fi
			return 0
			;;
		$'\x1b[D')
			MENU_BACK=1
			return 0
			;;
		$'\x1b[C')
			if [[ ${APP_BREW} -eq 0 && ${APP_CLAUDE} -eq 0 ]]; then
				continue
			fi
			return 0
			;;
		q|Q)
			MENU_QUIT=1
			return 0
			;;
		esac
	done
}

menu_configs_multi() {
	local idx=0
	local options=("zsh" "tmux" "vim" "neovim" "ghostty")
	local desc=("~/.zshrc and ~/.p10k.zsh" "~/.tmux.conf" "~/.vimrc" "~/.config/nvim" "~/.config/ghostty")
	local key i checked selected_total

	MENU_BACK=0
	MENU_QUIT=0

	while true; do
		clear_screen
		print_banner
		print_frame_header "$(action_label) 3/6" "Select Configs" 3

		for ((i = 0; i < ${#options[@]}; i++)); do
			checked="[ ]"
			case ${i} in
			0) [[ ${CFG_ZSH} -eq 1 ]] && checked="[x]" ;;
			1) [[ ${CFG_TMUX} -eq 1 ]] && checked="[x]" ;;
			2) [[ ${CFG_VIM} -eq 1 ]] && checked="[x]" ;;
			3) [[ ${CFG_NEOVIM} -eq 1 ]] && checked="[x]" ;;
			4) [[ ${CFG_GHOSTTY} -eq 1 ]] && checked="[x]" ;;
			esac
			if [[ ${idx} -eq ${i} ]]; then
				printf "  %b>%b %s %b%-8s%b %s\n" "${C_ACCENT}" "${C_RESET}" "${checked}" "${C_TITLE}" "${options[i]}" "${C_RESET}" "${desc[i]}"
			else
				printf "    %s %-8s %s\n" "${checked}" "${options[i]}" "${desc[i]}"
			fi
		done

		selected_total=$((CFG_ZSH + CFG_TMUX + CFG_VIM + CFG_NEOVIM + CFG_GHOSTTY))
		printf "\n  Selected: %b%s%b\n" "${C_ACCENT}" "${selected_total}" "${C_RESET}"

		print_frame_footer "[←] Back  [→] Next  [↑/↓] Navigate  [Space] Toggle"
		key=$(read_key) || continue
		case "${key}" in
		$'\x1b[A'|k)
			idx=$((idx - 1)); if [[ ${idx} -lt 0 ]]; then idx=4; fi
			;;
		$'\x1b[B'|j)
			idx=$((idx + 1)); if [[ ${idx} -gt 4 ]]; then idx=0; fi
			;;
		" ")
			case ${idx} in
			0) if [[ ${CFG_ZSH} -eq 1 ]]; then CFG_ZSH=0; else CFG_ZSH=1; fi ;;
			1) if [[ ${CFG_TMUX} -eq 1 ]]; then CFG_TMUX=0; else CFG_TMUX=1; fi ;;
			2) if [[ ${CFG_VIM} -eq 1 ]]; then CFG_VIM=0; else CFG_VIM=1; fi ;;
			3) if [[ ${CFG_NEOVIM} -eq 1 ]]; then CFG_NEOVIM=0; else CFG_NEOVIM=1; fi ;;
			4) if [[ ${CFG_GHOSTTY} -eq 1 ]]; then CFG_GHOSTTY=0; else CFG_GHOSTTY=1; fi ;;
			esac
			;;
		""|$'\n'|$'\r')
			if [[ $((CFG_ZSH + CFG_TMUX + CFG_VIM + CFG_NEOVIM + CFG_GHOSTTY)) -eq 0 ]]; then
				continue
			fi
			return 0
			;;
		$'\x1b[D')
			MENU_BACK=1
			return 0
			;;
		$'\x1b[C')
			if [[ $((CFG_ZSH + CFG_TMUX + CFG_VIM + CFG_NEOVIM + CFG_GHOSTTY)) -eq 0 ]]; then
				continue
			fi
			return 0
			;;
		q|Q)
			MENU_QUIT=1
			return 0
			;;
		esac
	done
}

append_command() {
	local cmd=$1
	COMMANDS+=("${cmd}")
}

build_commands() {
	COMMANDS=()

	if [[ "${SCOPE}" == "all" || "${SCOPE}" == "apps" ]]; then
		if [[ ${APP_BREW} -eq 1 ]]; then
			if [[ "${ACTION}" == "install" ]]; then
				append_command "./install.sh --apps brew ${BREW_MODE}"
			else
				append_command "./uninstall.sh --apps brew ${BREW_MODE}"
			fi
		fi
		if [[ ${APP_CLAUDE} -eq 1 ]]; then
			if [[ "${ACTION}" == "install" ]]; then
				append_command "./install.sh --apps claude"
			else
				append_command "./uninstall.sh --apps claude"
			fi
		fi
	fi

	if [[ "${SCOPE}" == "all" || "${SCOPE}" == "conf" ]]; then
		local conf_selected=$((CFG_ZSH + CFG_TMUX + CFG_VIM + CFG_NEOVIM + CFG_GHOSTTY))
		if [[ ${conf_selected} -eq 5 ]]; then
			if [[ "${ACTION}" == "install" ]]; then
				append_command "./install.sh --conf all"
			else
				append_command "./uninstall.sh --conf all"
			fi
		else
			if [[ ${CFG_ZSH} -eq 1 ]]; then
				if [[ "${ACTION}" == "install" ]]; then append_command "./install.sh --conf zsh"; else append_command "./uninstall.sh --conf zsh"; fi
			fi
			if [[ ${CFG_TMUX} -eq 1 ]]; then
				if [[ "${ACTION}" == "install" ]]; then append_command "./install.sh --conf tmux"; else append_command "./uninstall.sh --conf tmux"; fi
			fi
			if [[ ${CFG_VIM} -eq 1 ]]; then
				if [[ "${ACTION}" == "install" ]]; then append_command "./install.sh --conf vim"; else append_command "./uninstall.sh --conf vim"; fi
			fi
			if [[ ${CFG_NEOVIM} -eq 1 ]]; then
				if [[ "${ACTION}" == "install" ]]; then append_command "./install.sh --conf neovim"; else append_command "./uninstall.sh --conf neovim"; fi
			fi
			if [[ ${CFG_GHOSTTY} -eq 1 ]]; then
				if [[ "${ACTION}" == "install" ]]; then append_command "./install.sh --conf ghostty"; else append_command "./uninstall.sh --conf ghostty"; fi
			fi
		fi
	fi
}

print_preview() {
	local i
	clear_screen
	print_banner
	print_frame_header "$(action_label) 4/6" "Preview Commands" 4
	printf "  Planned commands:\n\n"
	for ((i = 0; i < ${#COMMANDS[@]}; i++)); do
		printf "  %b-%b %s\n" "${C_ACCENT}" "${C_RESET}" "${COMMANDS[i]}"
	done

	printf "\n  Managed path mapping:\n\n"
	printf "  - configs/zsh/zshrc -> ~/.zshrc\n"
	printf "  - configs/zsh/p10k.zsh -> ~/.p10k.zsh\n"
	printf "  - configs/tmux/tmux.conf -> ~/.tmux.conf\n"
	printf "  - configs/vi/vim/vimrc -> ~/.vimrc\n"
	printf "  - configs/vi/nvim -> ~/.config/nvim\n"
	printf "  - configs/ghostty -> ~/.config/ghostty\n"

	print_frame_footer "[←] Back  [→] Next  [Enter] Continue  [Q] Quit"
}

confirm_screen() {
	local idx=0
	local options=("Confirm and run" "Back to edit" "Quit")
	local key i

	MENU_BACK=0
	MENU_QUIT=0

	while true; do
		clear_screen
		print_banner
		print_frame_header "$(action_label) 5/6" "Confirm" 5

		if [[ "${ACTION}" == "uninstall" ]]; then
			printf "  %bWarning:%b uninstall removes managed symlinks and restores backups when found.\n\n" "${C_WARN}" "${C_RESET}"
		else
			printf "  Installer backs up existing files into %bbackups/%b when needed.\n\n" "${C_ACCENT}" "${C_RESET}"
		fi

		for ((i = 0; i < ${#options[@]}; i++)); do
			if [[ ${idx} -eq ${i} ]]; then
				printf "  %b>%b %b%s%b\n" "${C_ACCENT}" "${C_RESET}" "${C_TITLE}" "${options[i]}" "${C_RESET}"
			else
				printf "    %s\n" "${options[i]}"
			fi
		done

		print_frame_footer "[←] Back  [→] Next  [↑/↓] Navigate  [Enter] Select"
		key=$(read_key) || continue
		case "${key}" in
		$'\x1b[A'|k)
			idx=$((idx - 1)); if [[ ${idx} -lt 0 ]]; then idx=$((${#options[@]} - 1)); fi
			;;
		$'\x1b[B'|j)
			idx=$((idx + 1)); if [[ ${idx} -ge ${#options[@]} ]]; then idx=0; fi
			;;
		""|$'\n'|$'\r')
			MENU_RESULT=${idx}
			return 0
			;;
		$'\x1b[D')
			MENU_BACK=1
			return 0
			;;
		$'\x1b[C')
			MENU_RESULT=${idx}
			return 0
			;;
		q|Q)
			MENU_QUIT=1
			return 0
			;;
		esac
	done
}

draw_run_screen() {
	local done_count=$1
	local total_count=$2
	local success_count=$3
	local fail_count=$4
	local current_cmd=${5:-}

	clear_screen
	print_banner
	print_frame_header "$(action_label) 6/6" "Running" 6
	render_progress "${done_count}" "${total_count}"
	printf "\n"
	printf "  %bSummary:%b success=%d failed=%d\n" "${C_ACCENT}" "${C_RESET}" "${success_count}" "${fail_count}"
	printf "\n  %bCurrent:%b %s\n\n" "${C_TITLE}" "${C_RESET}" "${current_cmd}"
}

wait_finish_prompt() {
	printf "\n  Press Enter to finish..."
	read -r
}

run_commands() {
	local i
	local success_count=0
	local fail_count=0
	local done_count=0

	for ((i = 0; i < ${#COMMANDS[@]}; i++)); do
		draw_run_screen "${done_count}" "${#COMMANDS[@]}" "${success_count}" "${fail_count}" "${COMMANDS[i]}"
		printf "  %b[%d/%d]%b %s\n" "${C_ACCENT}" "$((i + 1))" "${#COMMANDS[@]}" "${C_RESET}" "${COMMANDS[i]}"
		if (cd "${script_dir}" && eval "${COMMANDS[i]}"); then
			success_count=$((success_count + 1))
			done_count=$((done_count + 1))
			printf "  %bOK%b\n\n" "${C_OK}" "${C_RESET}"
		else
			fail_count=$((fail_count + 1))
			done_count=$((done_count + 1))
			printf "  %bFAILED%b\n\n" "${C_ERROR}" "${C_RESET}"
			draw_run_screen "${done_count}" "${#COMMANDS[@]}" "${success_count}" "${fail_count}" "${COMMANDS[i]}"
			printf "  %bExecution stopped due to failure.%b\n" "${C_ERROR}" "${C_RESET}"
			wait_finish_prompt
			return 1
		fi
	done

	draw_run_screen "${done_count}" "${#COMMANDS[@]}" "${success_count}" "${fail_count}" ""
	printf "  %bDone.%b All commands succeeded.\n" "${C_OK}" "${C_RESET}"
	wait_finish_prompt
	return 0
}

main_loop() {
	while true; do
		case ${STEP} in
		1)
			menu_single "Welcome" "Choose Action" 1 "Install" "Uninstall" "Exit"
			if [[ ${MENU_QUIT} -eq 1 ]]; then return 0; fi
			if [[ ${MENU_RESULT} -eq 0 ]]; then
				ACTION="install"
			elif [[ ${MENU_RESULT} -eq 1 ]]; then
				ACTION="uninstall"
			else
				return 0
			fi
			STEP=2
			;;
		2)
			menu_single "$(action_label) 2/6" "Select Scope" 2 "All" "Apps only" "Config only"
			if [[ ${MENU_QUIT} -eq 1 ]]; then return 0; fi
			if [[ ${MENU_BACK} -eq 1 ]]; then STEP=1; continue; fi
			case ${MENU_RESULT} in
			0)
				SCOPE="all"
				APP_BREW=1
				APP_CLAUDE=1
				CFG_ZSH=1
				CFG_TMUX=1
				CFG_VIM=1
				CFG_NEOVIM=1
				CFG_GHOSTTY=1
				;;
			1)
				SCOPE="apps"
				APP_BREW=1
				APP_CLAUDE=0
				;;
			2)
				SCOPE="conf"
				CFG_ZSH=1
				CFG_TMUX=1
				CFG_VIM=1
				CFG_NEOVIM=1
				CFG_GHOSTTY=1
				;;
			esac
			STEP=3
			;;
		3)
			if [[ "${SCOPE}" == "all" || "${SCOPE}" == "apps" ]]; then
				menu_apps_multi
				if [[ ${MENU_QUIT} -eq 1 ]]; then return 0; fi
				if [[ ${MENU_BACK} -eq 1 ]]; then STEP=2; continue; fi
			fi
			if [[ "${SCOPE}" == "all" || "${SCOPE}" == "conf" ]]; then
				menu_configs_multi
				if [[ ${MENU_QUIT} -eq 1 ]]; then return 0; fi
				if [[ ${MENU_BACK} -eq 1 ]]; then
					if [[ "${SCOPE}" == "all" || "${SCOPE}" == "apps" ]]; then
						continue
					fi
					STEP=2
					continue
				fi
			fi
			build_commands
			if [[ ${#COMMANDS[@]} -eq 0 ]]; then
				STEP=3
			else
				STEP=4
			fi
			;;
			4)
				print_preview
				case "$(read_key)" in
				$'\x1b[D') STEP=3 ;;
				$'\x1b[C') STEP=5 ;;
				q|Q) return 0 ;;
				*) STEP=5 ;;
				esac
			;;
		5)
			confirm_screen
			if [[ ${MENU_QUIT} -eq 1 ]]; then return 0; fi
			if [[ ${MENU_BACK} -eq 1 ]]; then STEP=4; continue; fi
			case ${MENU_RESULT} in
			0) STEP=6 ;;
			1) STEP=3 ;;
			2) return 0 ;;
			esac
			;;
		6)
			run_commands
			return 0
			;;
		esac
	done
}

OS_DISPLAY=$(detect_os_display)
main_loop
