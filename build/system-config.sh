#!/usr/bin/env bash
# Deploy repo-managed SYSTEM-level config files to /etc (root-owned).
#
# home-manager can only own user-scope files (~/.config etc); root-level files
# are versioned in config/ and copied here. Currently handles:
#   - config/actkbd/  the keyboard backlight hotkey daemon
#   - config/udev/    udev rules (backlight boot floor; the systemd initramfs
#                     bundles these into the image for the LUKS prompt)
# Extend as more system config moves into the repo (tmpfiles, pacman.conf).
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SRC="$DIR/config/actkbd"
UDEV_SRC="$DIR/config/udev"
KBD_DEV="/dev/input/by-path/pci-0000:00:15.4-cs-00-event-kbd"

sudo install -Dm644 "$SRC/actkbd.conf" /etc/actkbd.conf
sudo install -Dm644 "$SRC/actkbd.service" /etc/systemd/system/actkbd.service
sudo install -Dm755 "$SRC/kbd-backlight-step" /usr/local/bin/kbd-backlight-step

# Deploy every udev rule from config/udev/. They must live in
# /etc/udev/rules.d for the systemd initramfs hook to bundle them.
for rule in "$UDEV_SRC"/*.rules; do
    [ -e "$rule" ] || continue
    sudo install -Dm644 "$rule" "/etc/udev/rules.d/$(basename "$rule")"
done

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

# Apply the backlight boot floor now: re-trigger the LED device so the new
# rule's RUN fires on the running system too (at boot it fires from the
# initramfs, before the LUKS prompt).
sudo udevadm trigger --subsystem-match=leds

echo "==> actkbd deployed. Enabled unit points at udev's own by-path symlink:"
echo "    $KBD_DEV"
echo "    Verify keycodes with:  sudo actkbd -n -s -d $KBD_DEV"
echo "==> udev rules deployed to /etc/udev/rules.d/ (rebuild initramfs to bundle them)"
