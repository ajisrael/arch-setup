#!/usr/bin/env bash
# Finalize a snapshot restore: make a booted-in snapshot the new root.
#
# Rolling back the root subvolume cannot be done while it is live as /, so
# the safe flow is:
#   1. build/snapshot.sh   (before the risky change)
#   2. reboot -> GRUB 'Snapshots' submenu -> pick the snapshot
#   3. verify the snapshot boots and works
#   4. build/restore.sh <name>   (this script, run from the snapshot)
#   5. reboot
#
# restore.sh swaps the subvolumes: the old root @ is renamed to @.old-<stamp>
# (kept as a safety net, never auto-deleted) and the snapshot you booted into
# takes over the @ name, so a plain boot then starts the restored system.
#
# Usage:
#   restore.sh list                 # show snapshots + which is currently booted
#   restore.sh <name>               # promote snapshot <name> to root @
#   restore.sh <name> --home        # also promote the matching <name>-home
#
# Must run from the snapshot (as root); refuses otherwise.
set -euo pipefail

SNAPSHOTS_DIR=/.snapshots

ORIG_ARGS=("$@")

usage() {
    sed -n '2,24p' "${BASH_SOURCE[0]}" | sed 's/^# //; /^$/d'
}

booted_snapshot() {
    # findmnt reports the btrfs subvol mount option as subvol=@snapshots/<name>
    # or subvol=/@snapshots/<name>; accept both. Empty when not in a snapshot.
    findmnt -no OPTIONS / | grep -oE 'subvol=/?@snapshots/[^,]*' | sed 's|subvol=/@snapshots/|@snapshots/|; s|subvol=@snapshots/|@snapshots/|' || true
}

list_snapshots() {
    echo "Snapshots in $SNAPSHOTS_DIR:"
    echo
    booted=$(booted_snapshot)
    booted="${booted#@snapshots/}"
    for snap in "$SNAPSHOTS_DIR"/*; do
        [ -d "$snap" ] || continue
        name=$(basename "$snap")
        marker=""
        [ "$name" = "$booted" ] && marker="  <-- currently booted"
        printf '  %s%s\n' "$name" "$marker"
    done
    echo
    echo "Booted root subvolume: ${booted:-@ (main system, not a snapshot)}"
}

if [ "${1:-}" = "list" ]; then
    list_snapshots
    exit 0
fi

[ $# -ge 1 ] || { usage >&2; exit 1; }
NAME="$1"
RESTORE_HOME=0
if [ "${2:-}" = "--home" ]; then
    RESTORE_HOME=1
fi

if [ "$(id -u)" -ne 0 ]; then
    exec sudo "$0" "${ORIG_ARGS[@]}"
fi

# Move out of /home etc. so later unmounts are not "target is busy".
cd /

# Unmount the top-level mount on failure so we never leave it half-moved.
TOP=/mnt/snap-restore
cleanup() {
    umount "$TOP" 2>/dev/null || true
    rmdir "$TOP" 2>/dev/null || true
}
trap cleanup EXIT

# Safety: must be booted into the snapshot we're promoting.
BOOTED=$(booted_snapshot)
if [ -z "$BOOTED" ]; then
    echo "error: not booted from a snapshot (root is the main @ subvolume)." >&2
    echo "Reboot and pick '$NAME' in the GRUB 'Snapshots' submenu first." >&2
    exit 1
fi
BOOTED_NAME="${BOOTED#@snapshots/}"
if [ "$BOOTED_NAME" != "$NAME" ]; then
    echo "error: you are booted into '$BOOTED_NAME' but asked to restore '$NAME'." >&2
    echo "Reboot and pick '$NAME' instead." >&2
    exit 1
fi

SNAP="$SNAPSHOTS_DIR/$NAME"
if [ ! -d "$SNAP" ]; then
    echo "error: no snapshot at $SNAP" >&2
    list_snapshots >&2
    exit 1
fi

# Find the btrfs device backing / so we can mount the top-level subvolume.
DEVICE=$(findmnt -no SOURCE /)
STAMP=$(date +%Y%m%d-%H%M%S)

echo "==> Booted from snapshot: $NAME"
echo "==> Mounting top-level subvolume from $DEVICE"
mkdir -p "$TOP"
mount -o subvolid=5 "$DEVICE" "$TOP"

echo "==> Keeping current root as @.old-$STAMP (safety net, not deleted)"
mv "$TOP/@" "$TOP/@.old-$STAMP"

echo "==> Promoting $SNAP -> @"
btrfs subvolume snapshot "$TOP/@snapshots/$NAME" "$TOP/@"

if [ "$RESTORE_HOME" = 1 ]; then
    HOME_SNAP="$SNAPSHOTS_DIR/${NAME}-home"
    if [ -d "$HOME_SNAP" ]; then
        # @home is still mounted at /home from fstab (unlike the root @, which
        # we replaced by booting into the snapshot). Unmount it first so the
        # subvolume is not busy, then swap it under the top-level mount.
        if mountpoint -q /home; then
            echo "==> Unmounting /home so @home can be swapped"
            umount /home
        fi
        echo "==> Keeping current home as @home.old-$STAMP"
        mv "$TOP/@home" "$TOP/@home.old-$STAMP"
        echo "==> Promoting ${NAME}-home -> @home"
        btrfs subvolume snapshot "$TOP/@snapshots/${NAME}-home" "$TOP/@home"
        echo "==> Remounting /home"
        mount /home
    else
        echo "!! No ${NAME}-home snapshot found; leaving @home untouched"
    fi
fi

echo
echo "==> Done. Reboot to start the restored system."
echo "    Old root kept as @.old-$STAMP; once you are happy, delete it with:"
echo "    mount -o subvolid=5 $DEVICE $TOP && btrfs subvolume delete $TOP/@.old-$STAMP && umount $TOP"
[ "$RESTORE_HOME" = 1 ] && echo "    Old home kept as @home.old-$STAMP (delete similarly)."

trap - EXIT
umount "$TOP"
rmdir "$TOP"
