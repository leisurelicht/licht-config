#!/usr/bin/env bash

script_dir=$(
	cd "$(dirname "${0}")" || exit
	pwd
)

exec "${script_dir}/scripts/install.sh" "$@"
