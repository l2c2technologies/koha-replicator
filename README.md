# Koha DB Transfer Automation

Automates secure, on-demand Koha database backups and transfers to a remote server using `rsync` and systemd timers.

**Author**: L2C2 Technologies  
**License**: GNU GPL v3+

---

## 🛠️ Overview

This system enables automated Koha database backups triggered via the `TransferDB` system preference and securely transfers them to a remote server. It consists of:

- SSH key generation and rsync user setup scripts.
- Backup and rsync upload script.
- Systemd service and timer for periodic execution.
- Key revocation mechanism.

---

## 📁 File Structure

| Path                                      | Purpose                                      |
|-------------------------------------------|----------------------------------------------|
| `/usr/local/bin/setup-rsync-sender.sh`    | Generates SSH key pair on the sender         |
| `/usr/local/bin/setup_rsync_receiver.sh`  | Sets up restricted rsync-only user on remote |
| `/usr/local/bin/upload_backup.sh`         | Performs Koha DB backup and rsync transfer   |
| `/usr/local/bin/revoke_rsync_access.sh`   | Revokes SSH key access from remote user      |
| `/etc/default/koha-transferdb`            | Configuration for Koha instance and transfer |
| `/etc/systemd/system/koha-transferdb.service` | Runs the upload script securely           |
| `/etc/systemd/system/koha-transferdb.timer`   | Triggers the service every minute         |

---

## 🧰 Setup Guide

### 1. On the **Sender (Koha server)**

#### a. Generate SSH key
```bash
sudo /usr/local/bin/setup-rsync-sender.sh
```
> Optionally use `-k /custom/path/to/key` to specify a non-default location.

#### b. Copy the public key output and keep it ready.

---

### 2. On the **Receiver (Backup server)**

#### a. Create restricted rsync user
```bash
sudo /usr/local/bin/setup_rsync_receiver.sh \
  -u backup_uploader \
  -k /path/to/copied/public_key.pub \
  -d /var/backups/koha
```

This:
- Creates a system user with no shell access.
- Restricts `rsync` access to the target directory only.
- Appends a forced `rsync` command to `authorized_keys`.

---

### 3. Configure Sender

Edit `/etc/default/koha-transferdb`:
```ini
KOHA_INSTANCE="koha_library"
REMOTE_SERVER="backup.example.com"
REMOTE_USER="backup_uploader"
REMOTE_PATH="/var/backups/koha"
KEY_PATH="/home/koha/.ssh/backup_key"
```

---

### 4. Enable systemd timer

```bash
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable --now koha-transferdb.timer
```

This runs the check every minute:
- If `TransferDB` system preference is set to `YES`, a backup is triggered and uploaded.
- The flag is reset automatically.

---

## 🔁 Usage

### Triggering a Backup
Set the system preference `TransferDB` to `YES`. The system will:
1. Detect the flag.
2. Perform backup with `koha-run-backups`.
3. Upload the latest backup via `rsync`.
4. Log the action and reset `TransferDB` to `NO`.

---

## 🚫 Revoking Access

If you need to revoke a public key:
```bash
sudo /usr/local/bin/revoke_rsync_access.sh -u backup_uploader -k /path/to/public_key.pub
```
This comments out the relevant line in `authorized_keys`.

---

## 🛡️ Security Notes

- SSH access is locked down with a forced `rsync` command and no shell.
- Keys can be revoked by commenting them in `authorized_keys`.
- Backups are transferred over encrypted SSH using a dedicated key pair.
