#!/bin/bash
# This script installs/upgrades pproxy, creates/updates a systemd service for it,
# and restarts the service with the specified configuration.
#
# Usage: ./setup_pproxy_service.sh <PORT> <USERNAME> <PASSWORD>
# Example: ./setup_pproxy_service.sh 1080 myuser mypass

set -euo pipefail

# --- Function to print error messages and exit ---
error_exit() {
    echo "Error: $1" >&2
    exit 1
}

# --- Validate arguments ---
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <PORT> <USERNAME> <PASSWORD>"
    exit 1
fi

PORT="$1"
USERNAME="$2"
PASSWORD="$3"

# --- Check if pip3 is installed; if not, update package list and install python3-pip ---
if ! command -v pip3 >/dev/null 2>&1; then
    echo "pip3 not found. Installing python3-pip..."
    sudo apt update || error_exit "Failed to update package list."
    sudo apt install -y python3-pip || error_exit "Failed to install python3-pip."
fi

# --- Install or upgrade pproxy using pip3 ---
echo "Installing/upgrading pproxy..."
pip3 install --upgrade pproxy || error_exit "Failed to install/upgrade pproxy."

# --- Locate the pproxy executable ---
PPROXY_PATH=$(command -v pproxy) || true
if [ -z "$PPROXY_PATH" ]; then
    error_exit "pproxy installation failed; executable not found."
fi
echo "pproxy installed at: $PPROXY_PATH"

# --- Define the systemd service file location ---
SERVICE_FILE="/etc/systemd/system/pproxy.service"
echo "Creating/updating service file: $SERVICE_FILE"

# --- Create or update the systemd service file with the specified configuration ---
sudo bash -c "cat > '$SERVICE_FILE'" <<EOF
[Unit]
Description=PPROXY Proxy Service
After=network.target

[Service]
ExecStart=$PPROXY_PATH -l "socks5+http://0.0.0.0:$PORT#$USERNAME:$PASSWORD"
Restart=always
User=nobody
Group=nogroup
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
EOF

# --- Reload systemd to pick up the new service file ---
echo "Reloading systemd configuration..."
sudo systemctl daemon-reload || error_exit "Failed to reload systemd configuration."

# --- Enable the service to start on boot ---
echo "Enabling pproxy service to start on boot..."
sudo systemctl enable pproxy.service || error_exit "Failed to enable pproxy.service."

# --- Restart the service if it's already running; otherwise, start it ---
if systemctl is-active --quiet pproxy.service; then
    echo "Restarting pproxy service..."
    sudo systemctl restart pproxy.service || error_exit "Failed to restart pproxy.service."
else
    echo "Starting pproxy service..."
    sudo systemctl start pproxy.service || error_exit "Failed to start pproxy.service."
fi

echo "pproxy is now running on port $PORT with authentication $USERNAME:$PASSWORD."