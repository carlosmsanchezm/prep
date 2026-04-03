#!/bin/bash
# Day 3: Debug Bash Scripts
# Each script below has bugs. Find and fix them.

# ============================================================
# Script 1: Service health checker (3 bugs)
# ============================================================

#!/bin/bash
set -euo pipefail

SERVICES="nginx sshd docker"

for svc in SERVICES; do
    status=$(systemctl is-active $svc)
    if [ $status = "active" ]; then
        echo "OK: $svc is running"
    else
        echo "FAIL: $svc is not running"
    fi
done

# What are the 3 bugs? Write fixes below:
# Bug 1:
# Bug 2:
# Bug 3:


# ============================================================
# Script 2: File backup with rotation (4 bugs)
# ============================================================

#!/bin/bash
set -euo pipefail

SOURCE_DIR=/var/data
BACKUP_DIR=/var/backups
MAX_BACKUPS=5

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/backup_$TIMESTAMP.tar.gz"

tar -czf $BACKUP_FILE $SOURCE_DIR

BACKUP_COUNT=$(ls $BACKUP_DIR/backup_*.tar.gz | wc -l)

if [ $BACKUP_COUNT -gt $MAX_BACKUPS ]; then
    OLDEST=$(ls -t $BACKUP_DIR/backup_*.tar.gz | tail -1)
    rm $OLDEST
    echo "Removed oldest backup: $OLDEST"
fi

echo "Backup complete: $BACKUP_FILE"

# What are the 4 bugs? Write fixes below:
# Bug 1:
# Bug 2:
# Bug 3:
# Bug 4:
