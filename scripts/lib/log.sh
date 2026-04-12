#!/bin/bash

is_tty() {
	[[ -t 1 ]]
}

init_log_style() {
	LOG_THEME=${LOG_THEME:-fancy}
	if [[ "${LOG_THEME}" != "fancy" && "${LOG_THEME}" != "minimal" ]]; then
		LOG_THEME="fancy"
	fi

	LOG_COLOR=0
	if is_tty && [[ -z "${NO_COLOR:-}" && "${TERM:-}" != "dumb" ]]; then
		LOG_COLOR=1
	fi

	if [[ ${LOG_COLOR} -eq 1 ]]; then
		LOG_RESET=$'\033[0m'
		LOG_BOLD=$'\033[1m'
		LOG_DIM=$'\033[2m'
		LOG_RED=$'\033[31m'
		LOG_YELLOW=$'\033[33m'
		LOG_BLUE=$'\033[34m'
		LOG_GREEN=$'\033[32m'
		LOG_MAGENTA=$'\033[35m'
	else
		LOG_RESET=""
		LOG_BOLD=""
		LOG_DIM=""
		LOG_RED=""
		LOG_YELLOW=""
		LOG_BLUE=""
		LOG_GREEN=""
		LOG_MAGENTA=""
	fi
}

_log_time() {
	if [[ "${LOG_SHOW_TIME:-1}" == "1" && "${LOG_THEME}" == "fancy" ]]; then
		date '+%H:%M:%S'
	else
		printf ''
	fi
}

_center_text() {
	local text=$1
	local width=${2:-7}
	local len=${#text}
	local left
	local right

	if ((len >= width)); then
		printf '%s' "${text}"
		return
	fi

	left=$(((width - len) / 2))
	right=$((width - len - left))
	printf '%*s%s%*s' "${left}" '' "${text}" "${right}" ''
}

_log_line() {
	local level=$1
	local color=$2
	local stream=${3:-1}
	shift 3
	local ts
	local level_cell
	ts=$(_log_time)
	level_cell=$(_center_text "${level}" 7)

	if [[ "${LOG_THEME}" == "minimal" ]]; then
		if [[ ${stream} -eq 2 ]]; then
			printf '%s[%s]%s %s\n' "${color}" "${level_cell}" "${LOG_RESET}" "$*" >&2
		else
			printf '%s[%s]%s %s\n' "${color}" "${level_cell}" "${LOG_RESET}" "$*"
		fi
	else
		if [[ ${stream} -eq 2 ]]; then
			printf '%s[%s]%s %s[%s]%s %s\n' \
				"${LOG_DIM}" "${ts}" "${LOG_RESET}" \
				"${color}" "${level_cell}" "${LOG_RESET}" "$*" >&2
		else
			printf '%s[%s]%s %s[%s]%s %s\n' \
				"${LOG_DIM}" "${ts}" "${LOG_RESET}" \
				"${color}" "${level_cell}" "${LOG_RESET}" "$*"
		fi
	fi
}

log_rule() {
	local width=${1:-76}
	local line
	line=$(printf '%*s' "${width}" '' | tr ' ' '-')
	printf '%s%s%s\n' "${LOG_DIM}" "${line}" "${LOG_RESET}"
}

log_section() {
	if [[ "${LOG_THEME}" == "minimal" ]]; then
		printf '\n'
		_log_line "SECTION" "${LOG_MAGENTA}${LOG_BOLD}" 1 "$*"
	else
		printf '\n'
		log_rule
		_log_line "SECTION" "${LOG_MAGENTA}${LOG_BOLD}" 1 "$*"
		log_rule
	fi
}

log_info() {
	_log_line "INFO" "${LOG_BLUE}" 1 "$*"
}

log_step() {
	_log_line "STEP" "${LOG_BLUE}" 1 "$*"
}

log_ok() {
	_log_line "OK" "${LOG_GREEN}" 1 "$*"
}

log_warn() {
	_log_line "WARN" "${LOG_YELLOW}" 2 "$*"
}

log_error() {
	_log_line "ERROR" "${LOG_RED}" 2 "$*"
}

log_dry() {
	_log_line "DRYRUN" "${LOG_DIM}" 1 "$*"
}
