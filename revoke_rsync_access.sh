#!/bin/bash

USERNAME=""
PUBKEY_FILE=""

usage() {
    echo "Usage: $0 -u USERNAME -k /path/to/public_key.pub"
    echo ""
    echo "Options:"
    echo "  -u USERNAME          Remote SSH user whose access is being revoked"
    echo "  -k PUBKEY_FILE       Path to the public key to be removed"
    echo ""
    exit 1
}

while getopts ":u:k:h" opt; do
  case $opt in
    u) USERNAME="$OPTARG" ;;
    k) PUBKEY_FILE="$OPTARG" ;;
    h) usage ;;
    *) echo "Invalid option: -$OPTARG" >&2; usage ;;
  esac
done

if [[ -z "$USERNAME" || -z "$PUBKEY_FILE" ]]; then
    echo "Error: Both username and pubkey path are required."
    usage
fi

KEY_CONTENT=$(cat "$PUBKEY_FILE" | grep -v '^#')

AUTH_KEYS="/home/$USERNAME/.ssh/authorized_keys"
TEMP_FILE=$(mktemp)

if grep -qF "$KEY_CONTENT" "$AUTH_KEYS"; then
    # Comment out matching line
    sudo awk -v key="$KEY_CONTENT" '{ if (index($0, key) > 0) print "# REVOKED " $0; else print $0; }' "$AUTH_KEYS" > "$TEMP_FILE"
    sudo mv "$TEMP_FILE" "$AUTH_KEYS"
    sudo chown "$USERNAME:$USERNAME" "$AUTH_KEYS"
    sudo chmod 600 "$AUTH_KEYS"
    echo "✅ Key access revoked for user $USERNAME."
else
    echo "❌ Key not found in $AUTH_KEYS."
    rm "$TEMP_FILE"
fi
