#!/bin/bash
# Day 1 ANSWERS: Bash Fill-in-the-Blanks

# BLANK 1: Safe scripting header
set -euo pipefail

MANIFEST_FILE="${1:-manifest.sha256}"
TARGET_DIR="${2:-/opt/bundles}"

# BLANK 2: Log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# BLANK 3: Check manifest exists
if [[ ! -f "$MANIFEST_FILE" ]]; then
    log "ERROR: Manifest file not found: $MANIFEST_FILE"
    exit 1
fi

# BLANK 4: Create target dir if missing
if [[ ! -d "$TARGET_DIR" ]]; then
    mkdir -p "$TARGET_DIR"
fi

PASS_COUNT=0
FAIL_COUNT=0

# BLANK 5: Read manifest line by line
while IFS= read -r line; do
    expected_hash=$(echo "$line" | awk '{print $1}')
    filename=$(echo "$line" | awk '{print $2}')

    # BLANK 6: Check if file exists
    if [[ ! -f "$TARGET_DIR/$filename" ]]; then
        log "MISSING: $filename"
        ((FAIL_COUNT++))
        continue
    fi

    # BLANK 7: Calculate sha256
    actual_hash=$(sha256sum "$TARGET_DIR/$filename" | awk '{print $1}')

    # BLANK 8: Compare hashes
    if [[ "$expected_hash" == "$actual_hash" ]]; then
        log "PASS: $filename"
        ((PASS_COUNT++))
    else
        log "FAIL: $filename (expected: $expected_hash, got: $actual_hash)"
        ((FAIL_COUNT++))
    fi

# BLANK 9: Close while loop
done < "$MANIFEST_FILE"

log "Results: $PASS_COUNT passed, $FAIL_COUNT failed"

# BLANK 10: Exit with error if failures
if [[ $FAIL_COUNT -gt 0 ]]; then
    exit 1
fi
