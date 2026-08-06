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

sudo install -Dm644 "$SRC/actkbd.conf" /etc/actkbd.conf
sudo install -Dm644 "$SRC/actkbd.service" /etc/systemd/system/actkbd.service
sudo install -Dm644 "$SRC/70-applespi-actkbd.rules" /etc/udev/rules.d/70-applespi-actkbd.rules
sudo install -Dm755 "$SRC/kbd-backlight-step" /usr/local/bin/kbd-backlight-step

sudo systemctl daemon-reload

# actkbd opens its device with fopen("a+"), which CREATES a regular file if
# the path does not exist yet. A leftover bogus file at /dev/input/actkbd-kbd
# (from a run that raced udev) must be removed or udev cannot create the
# symlink over it.
sudo rm -f /dev/input/actkbd-kbd
sudo udevadm control --reload
sudo udevadm trigger
# udevadm trigger is asynchronous; settle so the symlink exists before the
# service starts (the rule also starts it via SYSTEMD_WANTS).
sudo udevadm settle

# The unit is device-driven (no [Install]); drop any stale enable symlink from
# an older version of this script.
sudo rm -f /etc/systemd/system/multi-user.target.wants/actkbd.service

sudo systemctl restart actkbd.service

echo "==> actkbd deployed. The service is started by udev when the keyboard appears."
echo "    Verify keycodes with:  sudo actkbd -n -s -d /dev/input/actkbd-kbd"
