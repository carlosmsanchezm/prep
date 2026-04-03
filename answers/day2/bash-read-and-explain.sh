#!/bin/bash
# Day 2 ANSWERS: Read and Explain

# Q1: What does this script do overall?
# It imports container image archives from a bundle directory into a local Docker
# registry. It validates each archive, extracts images, loads them into Docker,
# tags them for the target registry, and pushes them.

# Q2: What does "set -euo pipefail" do?
# -e: exit immediately if any command fails (non-zero exit code)
# -u: treat undefined variables as an error (prevents typo bugs)
# -o pipefail: if any command in a pipe fails, the whole pipe fails
#              (without this, only the last command's exit code matters)

# Q3: What does the trap command do here?
# trap cleanup EXIT — runs the cleanup() function whenever the script exits,
# whether it succeeds, fails, or is interrupted (Ctrl+C). This ensures temp
# files in WORK_DIR are always deleted, even on error.

# Q4: What happens if an archive is corrupt?
# tar -tzf tests the archive without extracting. If it fails (&>/dev/null
# suppresses output), the script logs "ERROR: Corrupt archive", increments
# FAILED counter, and skips to the next archive with "continue".

# Q5: What does "${1:?Usage...}" mean?
# If $1 (first argument) is empty or unset, print the error message
# "Usage: $0 <bundle_dir>" and exit with code 1. It's a required argument check.

# Q6: Why does it use "tee -a" in the log function?
# tee writes to BOTH stdout (so you see it in the terminal) AND appends (-a) to
# the log file. Without tee, you'd have to choose one or the other.

# Q7: What's the exit code if any imports fail?
# Exit code 1. The last line: [[ $FAILED -eq 0 ]] || exit 1
# If FAILED is not zero, exit 1. If FAILED is zero, exit 0 (implicit).

# Q8: For a diode transfer instead of docker:
# - Replace "docker load/tag/push" with a copy to a staging directory
# - Add checksum validation (sha256sum) before and after transfer
# - Replace docker registry push with something like "skopeo copy" to Harbor
# - Add a manifest file that lists all transferred images + checksums
# - Add retry logic for diode latency/failures
