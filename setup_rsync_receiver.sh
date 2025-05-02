#!/bin/bash

# Default values
USERNAME=""
PUBKEY_FILE=""
DEST_DIR=""
HOME_BASE="/home"

# Usage information
usage() {
    echo "Usage: $0 -u USERNAME -k /path/to/public_key.pub -d /absolute/target/dir"
    echo ""
    echo "Options:"
    echo "  -u USERNAME              SSH username to create (e.g. 'backup_uploader')"
    echo "  -k PUBKEY_FILE           Path to public key file from local server"
    echo "  -d DEST_DIR              Absolute path to target directory for backups"
    echo ""
    echo "Example:"
    echo "  $0 -u backup_uploader -k ~/local_backup_key.pub -d /srv/backups/incoming"
    exit 1
}

# Parse command-line arguments
while getopts ":u:k:d:h" opt; do
  case $opt in
    u) USERNAME="$OPTARG" ;;
    k) PUBKEY_FILE="$OPTARG" ;;
    d) DEST_DIR="$OPTARG" ;;
    h) usage ;;
    *) echo "Invalid option: -$OPTARG" >&2; usage ;;
  esac
done

# Check required params
if [[ -z "$USERNAME" || -z "$PUBKEY_FILE" || -z "$DEST_DIR" ]]; then
    echo "Error: All parameters -u, -k, and -d are required."
    usage
fi

# Abort if user already exists
if id "$USERNAME" &>/dev/null; then
    echo "Error: User '$USERNAME' already exists."
    exit 1
fi

# Create the user without login shell
sudo adduser --disabled-password --shell /usr/sbin/nologin --gecos "" "$USERNAME"

# Create destination dir and set permissions
sudo mkdir -p "$DEST_DIR"
sudo chown "$USERNAME":"$USERNAME" "$DEST_DIR"
sudo chmod 700 "$DEST_DIR"

# Prepare SSH directory
USER_HOME="$HOME_BASE/$USERNAME"
SSH_DIR="$USER_HOME/.ssh"
AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"

sudo mkdir -p "$SSH_DIR"
sudo chmod 700 "$SSH_DIR"
sudo touch "$AUTHORIZED_KEYS"
sudo chmod 600 "$AUTHORIZED_KEYS"
sudo chown -R "$USERNAME:$USERNAME" "$SSH_DIR"

# Read public key and insert with restricted rsync forced command
PUBKEY_CONTENT=$(cat "$PUBKEY_FILE")

# This forces rsync to receive uploads only to $DEST_DIR
FORCED_CMD="command=\"rsync --server --sender -logDtpre . $DEST_DIR\",no-port-forwarding,no-agent-forwarding,no-X11-forwarding,no-pty $PUBKEY_CONTENT"

echo "$FORCED_CMD" | sudo tee -a "$AUTHORIZED_KEYS" > /dev/null

echo "✅ Setup complete. Restricted user '$USERNAME' can now upload to $DEST_DIR only."
echo "To revoke access, remove the key from: $AUTHORIZED_KEYS"
