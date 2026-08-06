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

sudo udevadm control --reload
sudo udevadm trigger
sudo systemctl daemon-reload
sudo systemctl enable actkbd.service
sudo systemctl restart actkbd.service

echo "==> actkbd deployed and enabled."
echo "    Verify keycodes with:  sudo actkbd -n -s -d /dev/input/actkbd-kbd"
