#!/bin/bash
# Day 4 ANSWERS: Bundle Validator Script

# Step 1
set -euo pipefail

# Step 2
BUNDLE_DIR="${1:-/opt/incoming}"
MANIFEST="${2:-$BUNDLE_DIR/manifest.sha256}"
DEST_DIR="${3:-/opt/registry/staging}"
LOG_FILE="/var/log/bundle-validate-$(date +%Y%m%d).log"

# Step 3
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Step 4
TEMP_DIR=""
cleanup() {
    if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup EXIT

TEMP_DIR=$(mktemp -d)

# Step 5
if [[ ! -d "$BUNDLE_DIR" ]]; then
    log "ERROR: Bundle directory not found: $BUNDLE_DIR"
    exit 1
fi

if [[ ! -f "$MANIFEST" ]]; then
    log "ERROR: Manifest file not found: $MANIFEST"
    exit 1
fi

# Step 6
mkdir -p "$DEST_DIR"

# Step 7
VALID=0
INVALID=0
MISSING=0

# Step 8
log "Starting bundle validation from $BUNDLE_DIR"

while IFS= read -r line; do
    # Skip empty lines and comments
    [[ -z "$line" || "$line" == \#* ]] && continue

    # a) Extract hash and filename
    expected_hash=$(echo "$line" | awk '{print $1}')
    filename=$(echo "$line" | awk '{print $2}')

    # b) Check if file exists
    filepath="$BUNDLE_DIR/$filename"

    if [[ ! -f "$filepath" ]]; then
        # c) Missing
        log "MISSING: $filename"
        ((MISSING++))
        continue
    fi

    # d) Calculate sha256
    actual_hash=$(sha256sum "$filepath" | awk '{print $1}')

    if [[ "$expected_hash" == "$actual_hash" ]]; then
        # e) Valid — copy to destination
        log "VALID: $filename"
        cp "$filepath" "$DEST_DIR/"
        ((VALID++))
    else
        # f) Invalid — hash mismatch
        log "INVALID: $filename (expected: $expected_hash, got: $actual_hash)"
        ((INVALID++))
    fi

done < "$MANIFEST"

# Step 9
log "========================================="
log "Validation complete:"
log "  Valid:   $VALID"
log "  Invalid: $INVALID"
log "  Missing: $MISSING"
log "========================================="

if [[ $INVALID -gt 0 || $MISSING -gt 0 ]]; then
    log "FAILED: $((INVALID + MISSING)) issues found"
    exit 1
else
    log "SUCCESS: All bundles validated"
    exit 0
fi
