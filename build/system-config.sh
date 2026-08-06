#!/usr/bin/env bash
# Deploy repo-managed SYSTEM-level config files to /etc (root-owned).
#
# home-manager can only own user-scope files (~/.config etc); root-level files
# are versioned in config/ and copied here. Currently handles actkbd (the
# keyboard backlight hotkey daemon). Extend as more system config moves into
# the repo (udev rules, tmpfiles, pacman.conf).
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SRC="$DIR/config/actkbd"
KBD_DEV="/dev/input/by-path/pci-0000:00:15.4-cs-00-event-kbd"

sudo install -Dm644 "$SRC/actkbd.conf" /etc/actkbd.conf
sudo install -Dm644 "$SRC/actkbd.service" /etc/systemd/system/actkbd.service
sudo install -Dm755 "$SRC/kbd-backlight-step" /usr/local/bin/kbd-backlight-step

sudo systemctl daemon-reload

# An earlier version used a custom udev rule + /dev/input/actkbd-kbd symlink.
# actkbd opens its device with fopen("a+"), which CREATES a regular file if
# the path is missing - so a bogus file can sit there and block the symlink,
# and udevadm trigger does not reliably re-create a symlink that was removed
# on an already-running box. Both are gone; clean up after that version.
sudo rm -f /dev/input/actkbd-kbd
sudo rm -f /etc/udev/rules.d/70-applespi-actkbd.rules
sudo udevadm control --reload

if [ ! -e "$KBD_DEV" ]; then
    echo "error: $KBD_DEV not found" >&2
    ls -l /dev/input/by-path/ 2>/dev/null || true
    exit 1
fi

sudo systemctl enable actkbd.service
sudo systemctl restart actkbd.service

echo "==> actkbd deployed. Enabled unit points at udev's own by-path symlink:"
echo "    $KBD_DEV"
echo "    Verify keycodes with:  sudo actkbd -n -s -d $KBD_DEV"
