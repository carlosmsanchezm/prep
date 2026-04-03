#!/bin/bash
# Day 1: Bash Fill-in-the-Blanks
# Fill in every line marked with ___BLANK___
# This script validates file checksums against a manifest

# BLANK 1: What should the first line after shebang be for safe scripting?
___BLANK___

MANIFEST_FILE="${1:-manifest.sha256}"
TARGET_DIR="${2:-/opt/bundles}"

# BLANK 2: Write a log function that prints timestamp + message
___BLANK___

# BLANK 3: Check if manifest file exists, exit 1 if not
___BLANK___

# BLANK 4: Check if target directory exists, create it if not
___BLANK___

PASS_COUNT=0
FAIL_COUNT=0

# BLANK 5: Read the manifest file line by line
___BLANK___
    expected_hash=$(echo "$line" | awk '{print $1}')
    filename=$(echo "$line" | awk '{print $2}')

    # BLANK 6: Check if the file exists in TARGET_DIR
    ___BLANK___
        log "MISSING: $filename"
        ((FAIL_COUNT++))
        continue
    fi

    # BLANK 7: Calculate the actual sha256 hash of the file
    actual_hash=$(___BLANK___)

    # BLANK 8: Compare expected vs actual hash
    ___BLANK___
        log "PASS: $filename"
        ((PASS_COUNT++))
    else
        log "FAIL: $filename (expected: $expected_hash, got: $actual_hash)"
        ((FAIL_COUNT++))
    fi

# BLANK 9: Close the while loop, reading from the manifest file
___BLANK___

log "Results: $PASS_COUNT passed, $FAIL_COUNT failed"

# BLANK 10: Exit with error code if any failures
___BLANK___
