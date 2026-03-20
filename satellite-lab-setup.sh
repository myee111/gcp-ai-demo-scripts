#!/usr/bin/env sh
# Satellite lab setup — SSH root login, sshd restart, and satellite.lab hosts entry.
# Backs up configs first. Must run as root (e.g. sudo ./satellite-lab-setup.sh).

set -eu

SSHD_CONFIG="${SSHD_CONFIG:-/etc/ssh/sshd_config}"

if [ ! -f "$SSHD_CONFIG" ]; then
  printf 'sshd config not found: %s\n' "$SSHD_CONFIG" >&2
  exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
  printf 'Run as root (e.g. sudo %s)\n' "$0" >&2
  exit 1
fi

ts="$(date +%Y%m%d%H%M%S)"
backup="${SSHD_CONFIG}.bak.${ts}"

cp -p "$SSHD_CONFIG" "$backup"
printf 'Backup: %s\n' "$backup"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

# First PermitRootLogin line becomes "yes"; extra PermitRootLogin lines removed; append if absent.
awk '
BEGIN { seen = 0 }
/^#?[ \t]*PermitRootLogin[ \t]/ {
  if (!seen) {
    print "PermitRootLogin yes"
    seen = 1
  }
  next
}
{ print }
END {
  if (!seen)
    print "PermitRootLogin yes"
}
' "$SSHD_CONFIG" > "$tmp"
cat "$tmp" > "$SSHD_CONFIG"

if sshd -t -f "$SSHD_CONFIG" 2>/dev/null; then
  printf 'sshd -t: configuration OK\n'
else
  printf 'Warning: sshd -t failed — restore with: cp %s %s\n' "$backup" "$SSHD_CONFIG" >&2
  exit 1
fi

# --- restart SSH so the new config is active ---
printf '\nRestarting SSH daemon...\n'
restarted=0

if command -v systemctl >/dev/null 2>&1; then
  if systemctl try-reload-or-restart sshd 2>/dev/null; then
    printf 'SSH: systemctl try-reload-or-restart sshd\n'
    restarted=1
  elif systemctl try-reload-or-restart ssh 2>/dev/null; then
    printf 'SSH: systemctl try-reload-or-restart ssh\n'
    restarted=1
  elif systemctl reload sshd 2>/dev/null; then
    printf 'SSH: systemctl reload sshd\n'
    restarted=1
  elif systemctl reload ssh 2>/dev/null; then
    printf 'SSH: systemctl reload ssh\n'
    restarted=1
  elif systemctl restart sshd 2>/dev/null; then
    printf 'SSH: systemctl restart sshd\n'
    restarted=1
  elif systemctl restart ssh 2>/dev/null; then
    printf 'SSH: systemctl restart ssh\n'
    restarted=1
  fi
fi

if [ "$restarted" -eq 0 ] && [ "$(uname -s)" = Darwin ] && command -v launchctl >/dev/null 2>&1; then
  if launchctl kickstart -k system/com.openssh.sshd 2>/dev/null; then
    printf 'SSH: launchctl kickstart -k system/com.openssh.sshd\n'
    restarted=1
  fi
fi

if [ "$restarted" -eq 0 ] && command -v service >/dev/null 2>&1; then
  if service sshd restart 2>/dev/null; then
    printf 'SSH: service sshd restart\n'
    restarted=1
  elif service ssh restart 2>/dev/null; then
    printf 'SSH: service ssh restart\n'
    restarted=1
  fi
fi

if [ "$restarted" -eq 0 ]; then
  printf 'Could not restart SSH automatically. Do it manually, e.g.:\n' >&2
  printf '  systemctl reload sshd || systemctl reload ssh\n' >&2
  printf '  macOS:\n' >&2
  printf '  launchctl kickstart -k system/com.openssh.sshd\n' >&2
  exit 1
fi

printf 'PermitRootLogin is now active.\n'

# --- /etc/hosts: satellite.lab ---
HOSTS_FILE="${HOSTS_FILE:-/etc/hosts}"
HOSTS_SATELLITE_IP="${HOSTS_SATELLITE_IP:-10.128.0.94}"
HOSTS_SATELLITE_NAME="${HOSTS_SATELLITE_NAME:-satellite.lab}"

if [ ! -f "$HOSTS_FILE" ]; then
  printf 'hosts file not found: %s\n' "$HOSTS_FILE" >&2
  exit 1
fi

hosts_backup="${HOSTS_FILE}.bak.${ts}"
cp -p "$HOSTS_FILE" "$hosts_backup"
printf '\nhosts backup: %s\n' "$hosts_backup"

hosts_tmp="$(mktemp)"
awk -v ip="$HOSTS_SATELLITE_IP" -v host="$HOSTS_SATELLITE_NAME" '
BEGIN { found = 0 }
/^[[:space:]]*#/ { print; next }
{
  skip = 0
  for (i = 2; i <= NF; i++) {
    if ($i == host) {
      if (!found) {
        print ip " " host
        found = 1
      }
      skip = 1
      break
    }
  }
  if (skip)
    next
  print
}
END {
  if (!found)
    print ip " " host
}
' "$HOSTS_FILE" > "$hosts_tmp"
cat "$hosts_tmp" > "$HOSTS_FILE"
rm -f "$hosts_tmp"

printf 'hosts: %s %s\n' "$HOSTS_SATELLITE_IP" "$HOSTS_SATELLITE_NAME"

# --- Register to Satellite ---
SATELLITE_ACTIVATION_KEYS="${SATELLITE_ACTIVATION_KEYS:-rhel}"
SATELLITE_LOCATION_ID="${SATELLITE_LOCATION_ID:-2}"
SATELLITE_ORG_ID="${SATELLITE_ORG_ID:-1}"
SATELLITE_TOKEN="${SATELLITE_TOKEN:-eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo0LCJpYXQiOjE3NzQwMjM5NDIsImp0aSI6IjMyMWE3YjIxNjAyZTYwNzkwMjJjYzI4MWM4MDk5OTM0MmY4NmY2M2IyY2Q1OTIxMjNkZDQ3MzA4ZjM3NWYzZmQiLCJzY29wZSI6InJlZ2lzdHJhdGlvbiNnbG9iYWwgcmVnaXN0cmF0aW9uI2hvc3QifQ.qXS2EpJS4jTycz7597GP9Kakqnij7aea_fMCeuvEHwk}"
SATELLITE_UPDATE_PACKAGES="${SATELLITE_UPDATE_PACKAGES:-false}"
SATELLITE_FORCE="${SATELLITE_FORCE:-true}"

printf '\nRegistering system to %s...\n' "$HOSTS_SATELLITE_NAME"

registration_url="https://${HOSTS_SATELLITE_NAME}/register"
registration_url="${registration_url}?activation_keys=${SATELLITE_ACTIVATION_KEYS}"
registration_url="${registration_url}&download_utility=curl"
registration_url="${registration_url}&force=${SATELLITE_FORCE}"
registration_url="${registration_url}&location_id=${SATELLITE_LOCATION_ID}"
registration_url="${registration_url}&organization_id=${SATELLITE_ORG_ID}"
registration_url="${registration_url}&update_packages=${SATELLITE_UPDATE_PACKAGES}"

if ! command -v curl >/dev/null 2>&1; then
  printf 'Error: curl not found. Install it first.\n' >&2
  exit 1
fi

if set -o pipefail && curl --silent --show-error --insecure "$registration_url" \
  --header "Authorization: Bearer ${SATELLITE_TOKEN}" | bash; then
  printf 'System registered to Satellite successfully.\n'
else
  printf 'Error: Failed to register system to Satellite.\n' >&2
  exit 1
fi
