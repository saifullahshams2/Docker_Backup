#!/bin/bash

# Configuration
SOURCE_DIR="/path/to/your/local/folder"  # Local folder to back up
REMOTE_USER="your_remote_username"       # Remote SSH username
REMOTE_HOST="your_remote_server_ip_or_hostname" # Remote server IP or hostname
REMOTE_DIR="/path/to/your/remote/backup/location" # Destination folder on the remote server
SSH_PORT="22" # SSH port, typically 22
IDENTITY_FILE="/path/to/your/ssh/private_key" # Path to your SSH private key (optional, if not using agent)

# --- DO NOT EDIT BELOW THIS LINE UNLESS YOU KNOW WHAT YOU ARE DOING ---

# Check if source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: Source directory '$SOURCE_DIR' does not exist."
    exit 1
fi

# Create a timestamp for the backup (e.g., 2023-10-27_10-30-00)
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_NAME="backup_$TIMESTAMP"

# Full path for the remote backup directory
FULL_REMOTE_PATH="$REMOTE_DIR/$BACKUP_NAME"

echo "Starting backup of '$SOURCE_DIR' to '$REMOTE_USER@$REMOTE_HOST:$FULL_REMOTE_PATH'..."

# Create the remote directory first
# The -p flag ensures parent directories are created if they don't exist
# We use -o StrictHostKeyChecking=no and -o UserKnownHostsFile=/dev/null for unattended execution
# For better security, consider adding the host to known_hosts instead of disabling checks.
ssh -p "$SSH_PORT" ${IDENTITY_FILE:+-i "$IDENTITY_FILE"} "$REMOTE_USER@$REMOTE_HOST" "mkdir -p $FULL_REMOTE_PATH"

if [ $? -ne 0 ]; then
    echo "Error: Could not create remote directory. Check SSH connection or permissions."
    exit 1
fi

# Use rsync for efficient backup
# -a: archive mode (preserves permissions, ownership, timestamps, etc.)
# -v: verbose output
# -z: compress file data during the transfer
# --delete: deletes extraneous files from destination dirs (if they don't exist in source) - USE WITH CAUTION!
#           Consider removing this if you want to keep old versions of files.
# --exclude: exclude specific files/directories (e.g., --exclude 'temp/*' --exclude '*.log')
# -e "ssh -p $SSH_PORT -i $IDENTITY_FILE": specify SSH as the remote shell and use the identity file
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

exit 0