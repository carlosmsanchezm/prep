#!/bin/bash
# Day 3 ANSWERS: Debug Bash Scripts

# ============================================================
# Script 1 Bugs:
# ============================================================

# Bug 1: for svc in SERVICES → should be for svc in $SERVICES
#   Without $, it iterates over the literal string "SERVICES", not its value

# Bug 2: [ $status = "active" ] → should be [[ "$status" == "active" ]]
#   - Use [[ ]] for string comparison (safer, handles empty strings)
#   - Quote "$status" (if empty, [ = "active" ] is a syntax error)
#   - Use == for string comparison in [[ ]]

# Bug 3: systemctl is-active can fail with set -e if service is inactive
#   systemctl is-active returns non-zero for inactive services
#   With set -e, the script exits immediately
#   Fix: status=$(systemctl is-active "$svc" 2>/dev/null || true)

# CORRECTED:
SERVICES="nginx sshd docker"

for svc in $SERVICES; do
    status=$(systemctl is-active "$svc" 2>/dev/null || true)
    if [[ "$status" == "active" ]]; then
        echo "OK: $svc is running"
    else
        echo "FAIL: $svc is not running"
    fi
done


# ============================================================
# Script 2 Bugs:
# ============================================================

# Bug 1: Variables not quoted — breaks on paths with spaces
#   tar -czf $BACKUP_FILE $SOURCE_DIR → tar -czf "$BACKUP_FILE" "$SOURCE_DIR"
#   Same for all variable references in file operations

# Bug 2: ls | wc -l is fragile — fails if no backups exist yet
#   ls will error with "no matches found" when no files match the glob
#   Fix: use find instead, or handle the case
#   BACKUP_COUNT=$(find "$BACKUP_DIR" -name "backup_*.tar.gz" | wc -l)

# Bug 3: ls -t ... | tail -1 gives the OLDEST by modification time
#   This is actually correct for removing oldest.
#   BUT: ls output parsing is fragile (filenames with spaces/newlines)
#   Fix: use find with -printf and sort
#   OLDEST=$(find "$BACKUP_DIR" -name "backup_*.tar.gz" -printf '%T+ %p\n' | sort | head -1 | cut -d' ' -f2)

# Bug 4: No check that BACKUP_DIR exists before writing
#   If /var/backups doesn't exist, tar fails
#   Fix: mkdir -p "$BACKUP_DIR"

# CORRECTED:
SOURCE_DIR="/var/data"
BACKUP_DIR="/var/backups"
MAX_BACKUPS=5

mkdir -p "$BACKUP_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/backup_$TIMESTAMP.tar.gz"

tar -czf "$BACKUP_FILE" "$SOURCE_DIR"

BACKUP_COUNT=$(find "$BACKUP_DIR" -name "backup_*.tar.gz" | wc -l)

if [[ "$BACKUP_COUNT" -gt "$MAX_BACKUPS" ]]; then
    OLDEST=$(find "$BACKUP_DIR" -name "backup_*.tar.gz" -printf '%T+ %p\n' | sort | head -1 | cut -d' ' -f2)
    rm "$OLDEST"
    echo "Removed oldest backup: $OLDEST"
fi

echo "Backup complete: $BACKUP_FILE"
