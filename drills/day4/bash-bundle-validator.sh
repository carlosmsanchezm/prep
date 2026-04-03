#!/bin/bash
# Day 4: Write a Bundle Validator Script
# This is guided — comments tell you what to write. Fill in the code.
# Simulates validating bundles transferred via diode.

# Step 1: Write the safe scripting header

# Step 2: Define variables
# - BUNDLE_DIR: first argument, default to /opt/incoming
# - MANIFEST: second argument, default to $BUNDLE_DIR/manifest.sha256
# - DEST_DIR: third argument, default to /opt/registry/staging
# - LOG_FILE: /var/log/bundle-validate-$(date +%Y%m%d).log
# Write these:


# Step 3: Write a log function that prints to both stdout and the log file


# Step 4: Write a cleanup function and trap it to EXIT


# Step 5: Validate that BUNDLE_DIR exists and MANIFEST file exists
# Exit with helpful error messages if not


# Step 6: Create DEST_DIR if it doesn't exist


# Step 7: Initialize counters: VALID=0, INVALID=0, MISSING=0


# Step 8: Read the manifest line by line
# Each line format: <sha256hash>  <filename>
# For each line:
#   a) Extract the hash and filename
#   b) Check if the file exists in BUNDLE_DIR
#   c) If missing: log "MISSING" and increment MISSING counter
#   d) If exists: calculate sha256 and compare
#   e) If match: log "VALID", copy to DEST_DIR, increment VALID
#   f) If mismatch: log "INVALID" with expected vs actual, increment INVALID
# Write this loop:


# Step 9: Print summary and exit
# Exit 0 if no failures, exit 1 if any INVALID or MISSING


