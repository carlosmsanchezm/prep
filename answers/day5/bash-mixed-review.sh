#!/bin/bash
# Day 5 ANSWERS: Mixed Bash Review

# ============================================================
# Part 1: FILL IN
# ============================================================

check_command() {
    # BLANK 1:
    if ! command -v "$1" &>/dev/null; then
        echo "ERROR: $1 is not installed" >&2
        exit 1
    fi
}

# BLANK 2:
check_command docker
check_command sha256sum

# ============================================================
# Part 2: DEBUG
# ============================================================

# Bug 1: $IMAGE should be $img
#   docker tag $img $REGISTRY/$IMAGE → docker tag "$img" "$REGISTRY/$img"
#   $IMAGE is never defined — it's $img

# Bug 2: Variables not quoted
#   docker pull $img → docker pull "$img"
#   If image name had spaces (unlikely but unsafe), it would break

# Bug 3: After pushing, local images pile up — no cleanup
#   Should add: docker rmi "$img" "$REGISTRY/$img" to avoid filling disk
#   (This is more of a best practice than a syntax bug)

# CORRECTED:
IMAGES="nginx:1.25 redis:7.2 postgres:16"
REGISTRY="harbor.local"

for img in $IMAGES; do
    echo "Pulling $img..."
    docker pull "$img"
    docker tag "$img" "$REGISTRY/$img"
    docker push "$REGISTRY/$img"
    echo "Pushed $img to $REGISTRY"
done

# ============================================================
# Part 3: SHORT WRITE
# ============================================================

#!/bin/bash
set -euo pipefail

DIR="${1:?Usage: $0 <directory>}"
COUNT=0

if [[ ! -d "$DIR" ]]; then
    echo "ERROR: Directory not found: $DIR" >&2
    exit 1
fi

for archive in "$DIR"/*.tar.gz; do
    [[ -f "$archive" ]] || continue
    size=$(du -h "$archive" | awk '{print $1}')
    echo "$(basename "$archive")  $size"
    ((COUNT++))
done

echo "---"
echo "Total archives: $COUNT"
