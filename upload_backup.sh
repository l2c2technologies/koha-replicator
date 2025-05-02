#!/bin/bash

# Defaults
KOHA_INSTANCE=""
REMOTE_SERVER=""
REMOTE_USER=""
REMOTE_PATH=""
KEY_PATH="$HOME/.ssh/backup_key"
BACKUP_DIR="/var/spool/koha"

# Help message
usage() {
    echo ""
    echo "Usage: $0 -i INSTANCE -r HOST -u USER -d DEST_PATH [-k KEY_PATH]"
    echo ""
    echo "This script backs up a Koha instance and transfers it via rsync over SSH."
    echo ""
    echo "Options:"
    echo "  -i, --instance   Koha instance name (required)"
    echo "  -r, --remote     Remote hostname or IP (required)"
    echo "  -u, --user       Remote SSH username (required)"
    echo "  -d, --dest       Remote absolute path to save backup (required)"
    echo "  -k, --key        SSH private key path (default: ~/.ssh/backup_key)"
    echo "  -h, --help       Display this help message"
    exit 1
}

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -i|--instance) KOHA_INSTANCE="$2"; shift ;;
        -r|--remote) REMOTE_SERVER="$2"; shift ;;
        -u|--user) REMOTE_USER="$2"; shift ;;
        -d|--dest) REMOTE_PATH="$2"; shift ;;
        -k|--key) KEY_PATH="$2"; shift ;;
        -h|--help) usage ;;
        *) echo "Unknown parameter: $1"; usage ;;
    esac
    shift
done

# Validate inputs
if [[ -z "$KOHA_INSTANCE" || -z "$REMOTE_SERVER" || -z "$REMOTE_USER" || -z "$REMOTE_PATH" ]]; then
    echo "❌ Error: Missing required parameters"
    usage
fi

FULL_BACKUP_DIR="${BACKUP_DIR}/${KOHA_INSTANCE}"

log_action() {
    local action=$1
    local info=$2
    echo "INSERT INTO action_logs (timestamp, user, module, action, object, info, interface) VALUES (NOW(), 0, 'CRONJOBS', '$action', NULL, '$info', 'cron');" | koha-mysql "$KOHA_INSTANCE"
}

check_transferdb() {
    local result
    result=$(echo "SELECT value FROM systempreferences WHERE variable='TransferDB';" | koha-mysql "$KOHA_INSTANCE" | tail -1)
    if [[ "$result" == "YES" ]]; then
        local user
        user=$(echo "SELECT user FROM action_logs WHERE module='SYSTEMPREFERENCE' AND action='MODIFY' AND info LIKE 'TransferDB | YES%' ORDER BY timestamp DESC LIMIT 1;" | koha-mysql "$KOHA_INSTANCE" | tail -1)
        echo "$user"
        return 0
    else
        return 1
    fi
}

# Begin process
log_action "Run" "Checking TransferDB flag"
if user=$(check_transferdb); then
    log_action "MODIFY" "TransferDB set to YES by user $user, initiating backup and transfer"

    echo "UPDATE systempreferences SET value='NO' WHERE variable='TransferDB';" | koha-mysql "$KOHA_INSTANCE"
    log_action "MODIFY" "TransferDB reset to NO"

    log_action "Run" "Starting koha-run-backups"
    if sudo koha-run-backups --exclude-indexes false --exclude-logs false "$KOHA_INSTANCE" > /dev/null 2>&1; then
        BACKUP_FILE=$(ls -t "${FULL_BACKUP_DIR}/${KOHA_INSTANCE}-"*.sql.gz | head -n 1)
        if [[ -z "$BACKUP_FILE" ]]; then
            log_action "ERROR" "Backup file not found"
            exit 1
        fi
        log_action "SUCCESS" "Backup completed: $(basename "$BACKUP_FILE")"

        # Transfer via rsync
        log_action "Run" "Starting rsync transfer to ${REMOTE_USER}@${REMOTE_SERVER}:${REMOTE_PATH}"
        if rsync -avz -e "ssh -i $KEY_PATH" "$BACKUP_FILE" "${REMOTE_USER}@${REMOTE_SERVER}:${REMOTE_PATH}/"; then
            log_action "SUCCESS" "Backup file transferred via rsync to remote"
        else
            log_action "ERROR" "rsync transfer failed"
        fi
    else
        log_action "ERROR" "koha-run-backups failed"
    fi
else
    log_action "INFO" "TransferDB is not enabled. No action taken."
fi

log_action "End" "DB transfer script finished"
