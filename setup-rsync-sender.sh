#!/bin/bash

KEY_PATH="$HOME/.ssh/backup_key"
usage() {
    echo "Usage: $0 [-k /custom/path/to/key]"
    echo ""
    echo "This script generates an SSH key pair to use for rsync transfers."
    echo "You must then pass the public key to the remote setup script."
    echo ""
    echo "Options:"
    echo "  -k /path/to/key       Custom private key path (default: ~/.ssh/backup_key)"
    echo ""
    exit 1
}

while getopts ":k:h" opt; do
  case $opt in
    k) KEY_PATH="$OPTARG" ;;
    h) usage ;;
    *) echo "Invalid option: -$OPTARG" >&2; usage ;;
  esac
done

PUB_KEY="${KEY_PATH}.pub"
KEY_DIR=$(dirname "$KEY_PATH")

# Ensure key directory exists
mkdir -p "$KEY_DIR"
chmod 700 "$KEY_DIR"

# Generate SSH key if it doesn't already exist
if [[ -f "$KEY_PATH" ]]; then
    echo "✅ SSH key already exists at $KEY_PATH"
else
    ssh-keygen -t rsa -b 4096 -f "$KEY_PATH" -N ""
    echo "✅ SSH key pair generated:"
    echo "  Private: $KEY_PATH"
    echo "  Public : $PUB_KEY"
fi

# Show public key
echo ""
echo "📋 Copy the following public key to your remote server setup script:"
echo "------------------------------------------------------------"
cat "$PUB_KEY"
echo "------------------------------------------------------------"
