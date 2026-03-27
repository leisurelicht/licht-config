#!/bin/bash

set -e

if ! command -v brew >/dev/null 2>&1; then
	echo "Error: Homebrew is not installed"
	echo "Install it from: https://brew.sh"
	exit 1
fi

# Add custom tap for dippy
if ! brew tap | grep -q "ldayton/dippy"; then
	echo "Adding tap: ldayton/dippy"
	brew tap ldayton/dippy
fi

# Install dippy
if brew list --formula "dippy" >/dev/null 2>&1; then
	echo "[OK] dippy already installed"
else
	echo "[Installing] dippy"
	if ! brew install dippy; then
		echo "[Error] Failed to install dippy"
		exit 1
	fi
fi

echo "Done!"
