#!/usr/bin/env bash
# Create btrfs snapshots of the system so a broken state can be rolled back.
#
# Snapshots the root subvolume (@) into the dedicated @snapshots subvolume
# (mounted at /.snapshots), regenerates the GRUB menu so the snapshot can be
# booted into (config/grub.d/40-snapshots), and prunes old snapshots.
#
# Snapshots are read-write on purpose: read-only snapshots can fail to boot
# (services need a writable root). Booting into a snapshot via the GRUB
# "Snapshots" submenu gives a bootable rollback point; run build/restore.sh
# from there to make it the default boot.
#
# Usage:
#   snapshot.sh                      # snapshot @, keep last 5
#   snapshot.sh --home               # also snapshot @home
#   snapshot.sh --keep 10            # prune to keep 10 root snapshots
#   snapshot.sh --label before-rice  # add a readable label to the name
#
# Needs root; reruns itself with sudo if not.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SNAPSHOTS_DIR=/.snapshots
KEEP=5
HOME=0
LABEL=""

ORIG_ARGS=("$@")

usage() {
    sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# //; /^$/d'
}

while [ $# -gt 0 ]; do
    case "$1" in
        --home) HOME=1 ;;
        --keep) KEEP="$2"; shift ;;
        --label) LABEL="$2"; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown arg: $1" >&2; usage >&2; exit 1 ;;
    esac
    shift
done

if [ "$(id -u)" -ne 0 ]; then
    exec sudo "$0" "${ORIG_ARGS[@]}"
fi

if ! command -v btrfs >/dev/null 2>&1; then
    echo "error: btrfs-progs not installed" >&2
    exit 1
fi

if [ ! -r /etc/grub.d/40-snapshots ]; then
    echo "warning: /etc/grub.d/40-snapshots not deployed; boot entries will be"
    echo "         missing. Run build/system-config.sh first to deploy it."
fi

# Sanitize the label into a filename-safe slug.
LABEL=$(printf '%s' "$LABEL" | tr -cd 'A-Za-z0-9._-')
STAMP=$(date +%Y%m%d-%H%M%S)
NAME="$STAMP${LABEL:+-$LABEL}"

mkdir -p "$SNAPSHOTS_DIR"

echo "==> Snapshotting root (@) -> $SNAPSHOTS_DIR/$NAME"
btrfs subvolume snapshot / "$SNAPSHOTS_DIR/$NAME"

if [ "$HOME" = 1 ]; then
    echo "==> Snapshotting home (@home) -> $SNAPSHOTS_DIR/${NAME}-home"
    btrfs subvolume snapshot /home "$SNAPSHOTS_DIR/${NAME}-home"
fi

echo "==> Refreshing GRUB menu (snapshot entries)"
sudo grub-mkconfig -o /boot/grub/grub.cfg >/dev/null

# Prune: keep the newest $KEEP root snapshots (and their matching -home).
mapfile -t snaps < <(find "$SNAPSHOTS_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %f\n' | sort -rn)
pruned=0
count=0
for entry in "${snaps[@]}"; do
    [ -n "$entry" ] || continue
    snap="${entry#* }"
    case "$snap" in *-home) continue ;; esac   # only count root snapshots
    count=$((count + 1))
    if [ "$count" -le "$KEEP" ]; then continue; fi
    echo "==> Pruning old snapshot: $snap"
    btrfs subvolume delete "$SNAPSHOTS_DIR/$snap"
    if [ -d "$SNAPSHOTS_DIR/${snap}-home" ]; then
        btrfs subvolume delete "$SNAPSHOTS_DIR/${snap}-home"
    fi
    pruned=$((pruned + 1))
done

if [ "$pruned" -gt 0 ]; then
    echo "==> Refreshing GRUB menu (pruned snapshots)"
    sudo grub-mkconfig -o /boot/grub/grub.cfg >/dev/null
fi

echo "==> Done. To roll back: reboot -> GRUB 'Snapshots' submenu -> $NAME,"
echo "    verify, then run: sudo $DIR/build/restore.sh $NAME"
