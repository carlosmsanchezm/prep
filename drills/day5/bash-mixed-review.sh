#!/bin/bash
# Day 5: Mixed Bash Review
# A mix of fill-in, debug, and short writes. Tests everything from the week.

# ============================================================
# Part 1: FILL IN (5 blanks)
# ============================================================

# Write a function that checks if a command exists on the system
# and exits with an error if it doesn't.
check_command() {
    # BLANK 1: check if the command exists
    ___BLANK___
        echo "ERROR: $1 is not installed" >&2
        exit 1
    fi
}

# Use it to check for docker and sha256sum
# BLANK 2: call the function for both
___BLANK___

# ============================================================
# Part 2: DEBUG (find 3 bugs)
# ============================================================

#!/bin/bash
set -euo pipefail

IMAGES="nginx:1.25 redis:7.2 postgres:16"
REGISTRY="harbor.local"

for img in $IMAGES; do
    echo "Pulling $img..."
    docker pull $img
    docker tag $img $REGISTRY/$IMAGE
    docker push $REGISTRY/$IMAGE
    echo "Pushed $img to $REGISTRY"
done

# What are the 3 bugs?
# Bug 1:
# Bug 2:
# Bug 3:

# ============================================================
# Part 3: SHORT WRITE
# ============================================================

# Write a script that:
# 1. Takes a directory path as argument
# 2. Finds all .tar.gz files in that directory
# 3. For each file, prints its name and size in human-readable format
# 4. At the end, prints the total count of archives found

# YOUR ANSWER (10-15 lines):

