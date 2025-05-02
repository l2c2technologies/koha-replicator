
# Koha Database Transfer Automation

This script automates monitoring and transferring Koha database backups when the `TransferDB` system preference is enabled.

---

## Table of Contents
- [Purpose](#purpose)
- [Features](#features)
- [Requirements](#requirements)
- [Configuration](#configuration)
- [Usage](#usage)
- [Cron Setup](#cron-setup)
- [Operation Flow](#operation-flow)
- [Troubleshooting](#troubleshooting)
- [Logging](#logging)
- [Security](#security)
- [Maintenance](#maintenance)
- [License](#license)
- [Author](#author)

---

## Purpose

Automates the process of:
1. Monitoring Koha's `TransferDB` system preference  
2. Initiating database backups when enabled  
3. Transferring backups to a remote server  
4. Logging all actions in Koha's action logs  

---

## Features

- **Preference Monitoring**: Checks `TransferDB` system preference every minute  
- **User Tracking**: Identifies which staff member triggered the transfer  
- **Automated Backups**: Uses Koha's built-in backup tools  
- **Secure Transfers**: Uses SCP for encrypted file transfer  
- **Comprehensive Logging**: Detailed action logging in Koha's database  
- **Self-cleaning**: Resets `TransferDB` preference after operation  

---

## Requirements

- Koha ILS installed and running  
- `koha-mysql` access configured  
- Passwordless SSH access to remote server configured  
- `sudo` access for running backups  
- Basic bash environment  

---

## Configuration

### Script Parameters

Configure via command line arguments:

| Parameter           | Description              | Example Value              |
|---------------------|--------------------------|----------------------------|
| `-i, --instance`    | Koha instance name       | `library`                  |
| `-r, --remote`      | Remote server hostname   | `backup.example.com`       |
| `-d, --dest`        | Remote destination path  | `/home/user/backups`       |
| `-b, --backupdir`   | Local backup directory   | `/var/spool/koha`          |

### SSH Setup

1. Generate SSH key (if not exists):

    ```bash
    ssh-keygen -t rsa -b 4096 -f ~/.ssh/koha_transfer
    ```

2. Copy to remote server:

    ```bash
    ssh-copy-id -i ~/.ssh/koha_transfer user@backup.example.com
    ```

3. Test connection:

    ```bash
    ssh -i ~/.ssh/koha_transfer user@backup.example.com
    ```

---

## Usage

Manual execution:

```bash
koha_transfer.sh --instance library \
                 --remote backup.example.com \
                 --dest /home/user/backups
```

Help display:

```bash
koha_transfer.sh --help
```

---

## Cron Setup

Add to cron to run every minute:

```bash
sudo crontab -e
```

Add line:

```bash
* * * * * /usr/local/bin/koha_transfer.sh --instance library --remote backup.example.com --dest /home/user/backups
```

Verify cron logs:

```bash
grep CRON /var/log/syslog
```

---

## Operation Flow

1. **Check Phase**:
   - Script starts and logs initiation  
   - Checks `TransferDB` system preference  
   - If YES, captures triggering user  

2. **Backup Phase**:
   - Resets `TransferDB` to NO  
   - Executes `koha-run-backups`  
   - Verifies backup file creation  

3. **Transfer Phase**:
   - Initiates SCP transfer to remote server  
   - Verifies transfer success  

4. **Completion**:
   - Logs final status  
   - Records completion time  

---

## Troubleshooting

### Common Issues

1. **Permission Denied**:

    ```bash
    sudo chmod 755 /usr/local/bin/koha_transfer.sh
    sudo chown root:root /usr/local/bin/koha_transfer.sh
    ```

2. **MySQL Connection Failed**:
   - Verify `koha-mysql` works manually  
   - Check Koha instance name is correct  

3. **SCP Transfer Fails**:
   - Test SSH connection manually  
   - Verify disk space on remote server  
   - Check directory permissions  

### Diagnostic Commands

Check last transfer:

```bash
echo "SELECT * FROM action_logs WHERE module='CRONJOBS' ORDER BY timestamp DESC LIMIT 10;" | koha-mysql library
```

Verify backup files:

```bash
ls -lh /var/spool/koha/library/
```

Test remote connection:

```bash
ssh user@backup.example.com "ls -lh /home/user/backups"
```

---

## Logging

All actions are logged to Koha's `action_logs` table with:

- Module: `CRONJOBS`  
- Interface: `cron`

Sample log entries:

```text
| timestamp           | user | module  | action | info                                 |
|---------------------|------|---------|--------|--------------------------------------|
| 2025-05-02 12:00:01 | 0    | CRONJOBS| Run    | Checking for DB Transfer             |
| 2025-05-02 12:00:02 | 0    | CRONJOBS| MODIFY | TransferDB set to YES by user 49     |
```

---

## Security

1. **SSH Security**:
   - Use dedicated SSH key  
   - Restrict remote user permissions  
   - Consider SSH config restrictions  

2. **File Permissions**:

    ```bash
    sudo chmod 750 /usr/local/bin/koha_transfer.sh
    ```

3. **Password Safety**:
   - Never store passwords in script  
   - Use SSH keys exclusively  

---

## Maintenance

### Regular Checks

1. Verify cron job is running:

    ```bash
    sudo systemctl status cron
    ```

2. Monitor disk space:

    ```bash
    df -h /var/spool/koha
    ```

3. Check remote storage:

    ```bash
    ssh user@backup.example.com "df -h /home/user/backups"
    ```

---

## Author

Developed by **L2C2 Technologies**

---
## License

This project is licensed under the **GNU General Public License v3.0 or later**.  
See [https://www.gnu.org/licenses/gpl-3.0.html](https://www.gnu.org/licenses/gpl-3.0.html) for more details.

---

