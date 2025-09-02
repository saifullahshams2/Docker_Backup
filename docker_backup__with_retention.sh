#!/bin/bash

# Configuration
SOURCE_DIR="/path/to/your/local/folder"  # Local folder to back up
REMOTE_USER="your_remote_username"       # Remote SSH username
REMOTE_HOST="your_remote_server_ip_or_hostname" # Remote server IP or hostname
REMOTE_DIR="/path/to/your/remote/backup/location" # Destination folder on the remote server
SSH_PORT="22" # SSH port, typically 22
IDENTITY_FILE="/path/to/your/ssh/private_key" # Path to your SSH private key (optional, if not using agent)

# Backup Retention Policy
# Number of days to keep backups. Backups older than this will be deleted.

RETENTION_DAYS=60 # Set to 30 or 60 as per your requirement

# --- DO NOT EDIT BELOW THIS LINE UNLESS YOU KNOW WHAT YOU ARE DOING ---

# Check if source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: Source directory '$SOURCE_DIR' does not exist."
    exit 1
fi

# Create a timestamp for the backup (e.g., 2023-10-27_10-30-00)
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M")

BACKUP_NAME="backup_$TIMESTAMP"

# Full path for the remote backup directory
FULL_REMOTE_PATH="$REMOTE_DIR/$BACKUP_NAME"

echo "Starting backup of '$SOURCE_DIR' to '$REMOTE_USER@$REMOTE_HOST:$FULL_REMOTE_PATH'..."

# Create the remote directory first
ssh -p "$SSH_PORT" ${IDENTITY_FILE:+-i "$IDENTITY_FILE"} "$REMOTE_USER@$REMOTE_HOST" "mkdir -p $FULL_REMOTE_PATH"

if [ $? -ne 0 ]; then
    echo "Error: Could not create remote directory. Check SSH connection or permissions."
    exit 1
fi

# Use rsync for efficient backup
rsync -avz --delete \
    -e "ssh -p $SSH_PORT ${IDENTITY_FILE:+-i "$IDENTITY_FILE"}" \
    "$SOURCE_DIR/" \
    "$REMOTE_USER@$REMOTE_HOST:$FULL_REMOTE_PATH"

if [ $? -eq 0 ]; then
    echo "Backup completed successfully to '$REMOTE_USER@$REMOTE_HOST:$FULL_REMOTE_PATH'."
else
    echo "Error: Backup failed. Please check the rsync output for details."
    exit 1
fi

echo "--- Starting backup retention cleanup ---"

# Calculate the cutoff date for old backups
# We use 'date' command to get a date string for comparison.
# This assumes backup folder names are in 'backup_YYYY-MM-DD_HH-MM-SS' format.

CUTOFF_DATE=$(date -d "$RETENTION_DAYS days ago" +"%Y-%m-%d")

echo "Deleting backups older than: $CUTOFF_DATE (Retention: $RETENTION_DAYS days)"

# Connect to the remote server and find/delete old backup directories
# 'find' is used to locate directories matching the backup pattern and older than the cutoff.
# We parse the date from the directory name and compare it.
# !IMPORTANT! This relies on the naming convention 'backup_YYYY-MM-DD_HH-MM-SS'.

ssh -p "$SSH_PORT" ${IDENTITY_FILE:+-i "$IDENTITY_FILE"} "$REMOTE_USER@$REMOTE_HOST" << EOF
    for dir in "$REMOTE_DIR"/backup_*-*-*_*-*-*; do
        if [ -d "\$dir" ]; then
            DIR_DATE=\$(echo "\$dir" | sed -n 's/.*backup_\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\).*/\1/p')
            if [[ -n "\$DIR_DATE" && "\$DIR_DATE" < "$CUTOFF_DATE" ]]; then
                echo "Deleting old backup: \$dir"
                rm -rf "\$dir"
            fi
        fi
    done
EOF

if [ $? -eq 0 ]; then
    echo "Backup retention cleanup completed successfully."
else
    echo "Error: Backup retention cleanup failed. Please check remote server logs."
fi

echo "Script finished."
exit 0