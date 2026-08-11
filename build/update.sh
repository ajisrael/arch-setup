#!/usr/bin/env bash
# Blessed system update flow: free-space check -> btrfs snapshot -> pacman -Syu
# (-> AUR refresh) -> restart prompt. Run this instead of bare `sudo pacman -Syu`.
#
# The snapshot is deliberately OPT-IN: there is no ALPM pre-transaction hook, so
# a bare `sudo pacman -Syu` behaves exactly as before (no auto-snapshot, no
# AbortOnFail surprises on every upgrade). If you bypass this wrapper, remember
# to run build/snapshot.sh yourself before a risky change.
#
# Usage:
#   update.sh          # interactive
#   update.sh -y       # skip the pre-flight confirmation
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
CONFIRM=1
FREE_MIN_MB=10240

usage() {
    sed -n '2,11p' "${BASH_SOURCE[0]}" | sed 's/^# //; s/^#$//; /^$/d'
}

while [ $# -gt 0 ]; do
    case "$1" in
        -y|--yes) CONFIRM=0 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown arg: $1" >&2; usage >&2; exit 1 ;;
    esac
    shift
done

# 1. Free-space check: / must hold the snapshot AND the package transaction.
#    btrfs snapshots are CoW but the transaction itself can be many GB.
free_kb=$(df -Pk --output=avail / | awk 'NR==2 {print $1}')
if [ -n "$free_kb" ] && [ "$free_kb" -lt $((FREE_MIN_MB * 1024)) ]; then
    echo "error: less than ${FREE_MIN_MB} MiB free on / (${free_kb} KiB)." >&2
    echo "       Free space first (pacman -Sc, btrfs balance)." >&2
    exit 1
fi

# 2. Snapshot BEFORE anything touches the system (the update.sh path is still
#    protected even if the ALPM hook is not yet deployed).
echo "==> Snapshotting current state (label pre-update)"
"$DIR/build/snapshot.sh" --label pre-update

# 3. Confirm + official repo upgrade.
if [ "$CONFIRM" = 1 ]; then
    read -r -p "==> Proceed with pacman -Syu? [y/N] " ans
    [[ "$ans" =~ ^[yY] ]] || { echo "aborted"; exit 0; }
fi

sudo pacman -Syu

# 4. AUR refresh, if there are foreign packages and paru is present.
if command -v paru >/dev/null 2>&1 && pacman -Qqm | grep -q .; then
    echo "==> Refreshing AUR packages (paru -Sua)"
    paru -Sua
fi

# 5. Restart prompt: a newer kernel image or systemd than the one running.
boot_ts=$(( $(date +%s) - $(awk '{print int($1)}' /proc/uptime) ))
newest_kernel=$(ls -t /boot/vmlinuz-* 2>/dev/null | head -1)
reboot=0
if [ -n "$newest_kernel" ] && [ "$(stat -c %Y "$newest_kernel")" -gt "$boot_ts" ]; then
    echo "==> Kernel image newer than boot; reboot to run it."
    reboot=1
fi
sysd_running=$(systemctl --version | awk 'NR==1 {print $2}')
sysd_pkg=$(pacman -Q systemd 2>/dev/null | awk '{print $2}')
if [ -n "$sysd_pkg" ] && [ "$sysd_running" != "$sysd_pkg" ]; then
    echo "==> systemd updated ($sysd_running -> $sysd_pkg); reboot recommended."
    reboot=1
fi

if [ "$reboot" = 1 ]; then
    read -r -p "==> Reboot now? [y/N] " ans
    if [[ "$ans" =~ ^[yY] ]]; then
        sudo systemctl reboot
    fi
else
    echo "==> No reboot needed. Done."
fi
