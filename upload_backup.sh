#!/bin/bash

CONFIG_FILE="/etc/default/koha-transferdb"

# Load config file
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    echo "❌ Config file not found: $CONFIG_FILE"
    exit 1
fi

# Validate required vars
if [[ -z "$KOHA_INSTANCE" || -z "$REMOTE_SERVER" || -z "$REMOTE_USER" || -z "$REMOTE_PATH" ]]; then
    echo "❌ One or more required config values are missing in $CONFIG_FILE"
    exit 1
fi

BACKUP_DIR="/var/spool/koha"
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

log_action "Run" "Checking TransferDB flag"
if user=$(check_transferdb); then
    log_action "MODIFY" "TransferDB set to YES by $user, triggering backup"

    echo "UPDATE systempreferences SET value='NO' WHERE variable='TransferDB';" | koha-mysql "$KOHA_INSTANCE"
    log_action "MODIFY" "TransferDB reset to NO"

    log_action "Run" "Running koha-run-backups"
    if sudo koha-run-backups --exclude-indexes false --exclude-logs false "$KOHA_INSTANCE" > /dev/null 2>&1; then
        BACKUP_FILE=$(ls -t "${FULL_BACKUP_DIR}/${KOHA_INSTANCE}-"*.sql.gz | head -n 1)
        if [[ -z "$BACKUP_FILE" ]]; then
            log_action "ERROR" "Backup file not found"
            exit 1
        fi
        log_action "SUCCESS" "Backup done: $(basename "$BACKUP_FILE")"

        log_action "Run" "Transferring backup via rsync"
        if rsync -avz -e "ssh -i $KEY_PATH" "$BACKUP_FILE" "${REMOTE_USER}@${REMOTE_SERVER}:${REMOTE_PATH}/"; then
            log_action "SUCCESS" "Transfer completed"
        else
            log_action "ERROR" "rsync failed"
        fi
    else
        log_action "ERROR" "koha-run-backups failed"
    fi
else
    log_action "INFO" "TransferDB is not enabled, skipping"
fi

log_action "End" "Script execution complete"
