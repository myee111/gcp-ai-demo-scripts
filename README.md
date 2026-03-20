# Bash Scripts

## Quick Install

Download and run the latest version directly from GitHub:

```bash
curl -fsSL https://raw.githubusercontent.com/myee111/gcp-ai-demo-scripts/main/install-satellite-lab.sh | sudo bash
```

Or download the installer first:

```bash
curl -fsSL -o install-satellite-lab.sh https://raw.githubusercontent.com/myee111/bash-scripting/main/install-satellite-lab.sh
chmod +x install-satellite-lab.sh
sudo ./install-satellite-lab.sh
```

## satellite-lab-setup.sh

Automated setup script for configuring a system to work with a Satellite lab environment.

### What it does

This script performs three main tasks:

1. **Enable SSH root login**
   - Backs up `/etc/ssh/sshd_config`
   - Sets `PermitRootLogin yes`
   - Validates and restarts SSH daemon
   - Works on Linux (systemd/service) and macOS (launchctl)

2. **Add satellite.lab to /etc/hosts**
   - Backs up `/etc/hosts`
   - Adds or updates entry for `satellite.lab` (default IP: 10.128.0.94)
   - Removes duplicate entries for the same hostname

3. **Register system to Satellite**
   - Uses the Satellite registration API with bearer token authentication
   - Downloads and executes the registration script from satellite.lab
   - Configurable activation keys, organization, and location

### Usage

```bash
sudo ./satellite-lab-setup.sh
```

**Must run as root** (uses sudo).

### Configuration

Override defaults with environment variables:

```bash
# SSH config
SSHD_CONFIG=/etc/ssh/sshd_config

# Hosts file
HOSTS_FILE=/etc/hosts
HOSTS_SATELLITE_IP=10.128.0.94
HOSTS_SATELLITE_NAME=satellite.lab

# Satellite registration
SATELLITE_ACTIVATION_KEYS=rhel
SATELLITE_LOCATION_ID=2
SATELLITE_ORG_ID=1
SATELLITE_TOKEN=eyJhbGci...
SATELLITE_UPDATE_PACKAGES=false
SATELLITE_FORCE=true
```

### Example with custom settings

```bash
sudo HOSTS_SATELLITE_IP=192.168.1.100 \
     SATELLITE_ACTIVATION_KEYS=prod \
     ./satellite-lab-setup.sh
```

### Backups

Creates timestamped backups before modifying files:
- `/etc/ssh/sshd_config.bak.YYYYMMDDHHMMSS`
- `/etc/hosts.bak.YYYYMMDDHHMMSS`

### Requirements

- Root access
- `curl` for Satellite registration
- `subscription-manager` (if registration fallback needed)

## install-satellite-lab.sh

Bootstrap installer that downloads and runs the latest `satellite-lab-setup.sh` from GitHub.

### How it works

1. Checks for root access (auto-elevates with sudo if needed)
2. Downloads the latest `satellite-lab-setup.sh` from the main branch
3. Makes it executable and runs it
4. Supports both curl and wget

### How to run

**One-liner (recommended):**

```bash
curl -fsSL https://raw.githubusercontent.com/myee111/gcp-ai-demo-scripts/main/install-satellite-lab.sh | sudo bash
```

**Or download first:**

```bash
curl -fsSL -o install-satellite-lab.sh https://raw.githubusercontent.com/myee111/bash-scripting/main/install-satellite-lab.sh
chmod +x install-satellite-lab.sh
sudo ./install-satellite-lab.sh
```

**With environment variables:**

```bash
curl -fsSL https://raw.githubusercontent.com/myee111/bash-scripting/main/install-satellite-lab.sh | \
  sudo HOSTS_SATELLITE_IP=192.168.1.100 SATELLITE_ACTIVATION_KEYS=prod bash
```

### Dependencies

- Root access (or sudo)
- `curl` or `wget`
