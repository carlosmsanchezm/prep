#!/bin/bash
# Day 2: Read and Explain
# Read this script and answer the questions below.
# Don't run it — just read and understand.

set -euo pipefail

BUNDLE_DIR="${1:?Usage: $0 <bundle_dir>}"
REGISTRY_URL="${2:-localhost:5000}"
LOG_FILE="/var/log/bundle-import-$(date +%Y%m%d).log"

log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

cleanup() {
    log "Cleaning up temp files..."
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

WORK_DIR=$(mktemp -d)
IMPORTED=0
FAILED=0

log "Starting bundle import from $BUNDLE_DIR"

for archive in "$BUNDLE_DIR"/*.tar.gz; do
    [[ -f "$archive" ]] || continue

    base=$(basename "$archive" .tar.gz)
    log "Processing: $base"

    if ! tar -tzf "$archive" &>/dev/null; then
        log "ERROR: Corrupt archive: $base"
        ((FAILED++))
        continue
    fi

    tar -xzf "$archive" -C "$WORK_DIR"

    for image_tar in "$WORK_DIR"/*.tar; do
        [[ -f "$image_tar" ]] || continue
        image_name=$(basename "$image_tar" .tar)

        if docker load -i "$image_tar" 2>/dev/null; then
            docker tag "$image_name" "$REGISTRY_URL/$image_name"
            docker push "$REGISTRY_URL/$image_name"
            log "Imported: $image_name → $REGISTRY_URL/$image_name"
            ((IMPORTED++))
        else
            log "ERROR: Failed to load $image_name"
            ((FAILED++))
        fi

        rm -f "$image_tar"
    done

    rm -rf "$WORK_DIR"/*
done

log "Complete. Imported: $IMPORTED, Failed: $FAILED"
[[ $FAILED -eq 0 ]] || exit 1

# QUESTIONS — Answer these without running the script:
#
# Q1: What does this script do overall? (2 sentences)
# YOUR ANSWER:
#
# Q2: What does "set -euo pipefail" do?
# YOUR ANSWER:
#
# Q3: What does the trap command do here?
# YOUR ANSWER:
#
# Q4: What happens if an archive is corrupt?
# YOUR ANSWER:
#
# Q5: What does "${1:?Usage...}" mean?
# YOUR ANSWER:
#
# Q6: Why does it use "tee -a" in the log function?
# YOUR ANSWER:
#
# Q7: What's the exit code if any imports fail?
# YOUR ANSWER:
#
# Q8: If you had to modify this for a diode transfer instead of docker,
#     what would you change?
# YOUR ANSWER:
