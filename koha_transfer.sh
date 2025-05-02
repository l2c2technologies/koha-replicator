#!/bin/bash

# Default values
KOHA_INSTANCE=""
REMOTE_SERVER=""
REMOTE_PATH=""
BACKUP_DIR="/var/spool/koha"

# Display usage information
usage() {
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "This script monitors Koha's TransferDB system preference and performs database backups and transfers when enabled."
    echo ""
    echo "Options:"
    echo "  -i, --instance INSTANCE   Koha instance name (required)"
    echo "  -r, --remote HOST         Remote server hostname (required)"
    echo "  -d, --dest PATH           Remote destination path (required)"
    echo "  -h, --help                Display this help message"
    echo ""
    echo "Example:"
    echo "  $0 --instance koha_library --remote backup.example.com \\"
    echo "     --dest /remote/backup/path"
    echo ""
    exit 1
}

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -i|--instance) KOHA_INSTANCE="$2"; shift ;;
        -r|--remote) REMOTE_SERVER="$2"; shift ;;
        -d|--dest) REMOTE_PATH="$2"; shift ;;
        -b|--backupdir) BACKUP_DIR="$2"; shift ;;
        -h|--help) usage ;;
        *) echo "Unknown parameter: $1"; usage ;;
    esac
    shift
done

# Validate parameters
if [[ -z "$KOHA_INSTANCE" || -z "$REMOTE_SERVER" || -z "$REMOTE_PATH" ]]; then
    echo "Error: Missing required parameters"
    usage
fi

# Construct full backup directory path
FULL_BACKUP_DIR="${BACKUP_DIR}/${KOHA_INSTANCE}"

# Log function
log_action() {
    local action=$1
    local info=$2
    echo "INSERT INTO action_logs (timestamp, user, module, action, object, info, interface) VALUES (NOW(), 0, 'CRONJOBS', '$action', NULL, '$info', 'cron');" | koha-mysql $KOHA_INSTANCE
}

# Check if TransferDB is set to YES (handles column headers in output)
check_transferdb() {
    local result=$(echo "SELECT value FROM systempreferences WHERE variable='TransferDB';" | koha-mysql $KOHA_INSTANCE | tail -1)
    if [ "$result" = "YES" ]; then
        # Get the user who set it to YES (handles column headers in output)
        local user=$(echo "SELECT user FROM action_logs WHERE module='SYSTEMPREFERENCE' AND action='MODIFY' AND info LIKE 'TransferDB | YES%' ORDER BY timestamp DESC LIMIT 1;" | koha-mysql $KOHA_INSTANCE | tail -1)
        echo "$user"
        return 0
    else
        return 1
    fi
}

# Main script
log_action "Run" "Checking for DB Transfer"

# Check TransferDB status
if user=$(check_transferdb); then
    log_action "MODIFY" "TransferDB set to YES by user $user, initiating transfer"
    
    # Reset TransferDB to NO
    echo "UPDATE systempreferences SET value='NO' WHERE variable='TransferDB';" | koha-mysql $KOHA_INSTANCE
    log_action "MODIFY" "Reset TransferDB to NO"
    
    # Run koha backup
    log_action "Run" "Starting database backup"
    if sudo koha-run-backups --exclude-indexes false --exclude-logs false $KOHA_INSTANCE > /dev/null 2>&1; then
        # Find the latest SQL dump file (not the tar.gz)
        BACKUP_FILE=$(ls -t ${FULL_BACKUP_DIR}/${KOHA_INSTANCE}-*.sql.gz | head -n 1)
        
        if [ -z "$BACKUP_FILE" ]; then
            log_action "ERROR" "SQL dump file not found after successful backup"
            exit 1
        fi
        
        log_action "SUCCESS" "Database backup completed: $(basename $BACKUP_FILE)"
        
        # Transfer to remote server
        log_action "Run" "Starting file transfer to remote server"
        if scp $BACKUP_FILE ${REMOTE_SERVER}:${REMOTE_PATH}/; then
            log_action "SUCCESS" "SQL dump transferred successfully to ${REMOTE_SERVER}:${REMOTE_PATH}/$(basename $BACKUP_FILE)"
        else
            log_action "ERROR" "Failed to transfer SQL dump to remote server"
        fi
    else
        log_action "ERROR" "Database backup failed"
    fi
else
    log_action "INFO" "TransferDB not set to YES, no action taken"
fi

log_action "End" "DB Transfer process completed"
