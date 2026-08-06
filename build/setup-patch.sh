#!/bin/bash
# Stage the local kernel patches for building on this machine.
#
# Copies rebuild.sh and the two patch files from this repo's build/ into a
# dedicated directory on this system (default ~/build/linux/), where
# rebuild.sh will clone the Arch packaging tree next to them. Run once after
# cloning this repo, and again after pulling in newer patch versions.
# Safe to re-run; takes an optional destination directory as $1.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEST="${1:-$HOME/build/linux}"

FILES=(
  rebuild.sh
  0001-spi-pxa2xx-macbookpro12-1-pio.patch
  0002-spi-pxa2xx-lpss-s3-resume.patch
)

mkdir -p "$DEST"
for f in "${FILES[@]}"; do
  cp "$SCRIPT_DIR/$f" "$DEST/"
done
chmod +x "$DEST/rebuild.sh"

echo "Staged $((${#FILES[@]})) build files in $DEST"
echo "Rebuild the patched kernel with: $DEST/rebuild.sh"
