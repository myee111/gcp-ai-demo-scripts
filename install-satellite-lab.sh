#!/usr/bin/env bash
# Bootstrap installer for satellite-lab-setup.sh
# Downloads and runs the latest version from GitHub

set -euo pipefail

REPO_URL="https://raw.githubusercontent.com/myee111/gcp-ai-demo-scripts/main/satellite-lab-setup.sh"
SCRIPT_NAME="satellite-lab-setup.sh"
TEMP_SCRIPT="/tmp/${SCRIPT_NAME}"

if [ "$(id -u)" -ne 0 ]; then
  printf 'This installer must run as root. Re-running with sudo...\n' >&2
  exec sudo "$0" "$@"
fi

# Setup logging
ts="$(date +%Y%m%d%H%M%S)"
LOG_FILE="/tmp/install-satellite-lab-${ts}.log"
exec > >(tee -a "$LOG_FILE") 2>&1
printf 'Logging to: %s\n\n' "$LOG_FILE"

printf 'Downloading %s from GitHub...\n' "$SCRIPT_NAME"

if command -v curl >/dev/null 2>&1; then
  if curl -fsSL -o "$TEMP_SCRIPT" "$REPO_URL"; then
    printf 'Downloaded successfully.\n'
  else
    printf 'Error: Failed to download script from %s\n' "$REPO_URL" >&2
    exit 1
  fi
elif command -v wget >/dev/null 2>&1; then
  if wget -q -O "$TEMP_SCRIPT" "$REPO_URL"; then
    printf 'Downloaded successfully.\n'
  else
    printf 'Error: Failed to download script from %s\n' "$REPO_URL" >&2
    exit 1
  fi
else
  printf 'Error: Neither curl nor wget found. Install one of them first.\n' >&2
  exit 1
fi

chmod +x "$TEMP_SCRIPT"

printf 'Running %s...\n\n' "$SCRIPT_NAME"
cd /tmp
exec "$TEMP_SCRIPT" "$@"
