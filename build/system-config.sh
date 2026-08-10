#!/usr/bin/env bash
# Deploy repo-managed SYSTEM-level config files to /etc (root-owned).
#
# home-manager can only own user-scope files (~/.config etc); root-level files
# are versioned in config/ and copied here. Currently handles:
#   - config/actkbd/     the keyboard backlight hotkey daemon
#   - config/modprobe.d/ modprobe.d install reroutes (backlight boot floor for
#                        the LUKS prompt; modconf bundles these into the image,
#                        which is rebuilt automatically when they change)
# Extend as more system config moves into the repo (udev rules, tmpfiles,
# pacman.conf).
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SRC="$DIR/config/actkbd"
MODPROBE_SRC="$DIR/config/modprobe.d"
GRUB_SRC="$DIR/config/grub.d"
KBD_DEV="/dev/input/by-path/pci-0000:00:15.4-cs-00-event-kbd"

sudo install -Dm644 "$SRC/actkbd.conf" /etc/actkbd.conf
sudo install -Dm644 "$SRC/actkbd.service" /etc/systemd/system/actkbd.service
sudo install -Dm755 "$SRC/kbd-backlight-step" /usr/local/bin/kbd-backlight-step

# Deploy every modprobe.d file from config/modprobe.d/. They must live in
# /etc/modprobe.d for the modconf initramfs hook to bundle them. Track whether
# any file actually changed, so the initramfs is only rebuilt when needed.
MODPROBE_CHANGED=0
for conf in "$MODPROBE_SRC"/*.conf; do
    [ -e "$conf" ] || continue
    dest="/etc/modprobe.d/$(basename "$conf")"
    cmp -s "$conf" "$dest" || MODPROBE_CHANGED=1
    sudo install -Dm644 "$conf" "$dest"
done

# Rebuild the initramfs when a modprobe.d file changed, so the boot-floor
# reroute inside the image matches /etc. mkinitcpio builds to a temp file and
# atomically replaces the image only on success, so a failed build cannot
# clobber a working one. Keep a copy of the previous images regardless.
REBUILD_INITRAMFS=0
if [ "$MODPROBE_CHANGED" = 1 ]; then
    REBUILD_INITRAMFS=1
fi

# Also rebuild if /etc/modprobe.d has files newer than the newest initramfs
# image - covers /etc being updated before this script started rebuilding
# automatically, which leaves the image stale.
newest_conf=$(ls -t /etc/modprobe.d/*.conf 2>/dev/null | head -1)
newest_img=$(ls -t /boot/initramfs-*.img 2>/dev/null | head -1)
if [ -n "$newest_conf" ] && [ -n "$newest_img" ] && [ "$newest_conf" -nt "$newest_img" ]; then
    REBUILD_INITRAMFS=1
fi

if [ "$REBUILD_INITRAMFS" = 1 ]; then
    BACKUP_DIR="/var/backup/initramfs-pre-modprobe"
    sudo mkdir -p "$BACKUP_DIR"
    stamp="$(date +%Y%m%d-%H%M%S)"
    for img in /boot/initramfs-*.img; do
        [ -e "$img" ] || continue
        sudo cp -a "$img" "$BACKUP_DIR/$(basename "$img").$stamp"
    done
    echo "==> modprobe.d changed or image stale; rebuilding initramfs (previous images in $BACKUP_DIR)"
    sudo mkinitcpio -P
fi

sudo systemctl daemon-reload

# Deploy every grub.d script from config/grub.d/ (currently 40-snapshots, the
# btrfs snapshot boot entries used by build/snapshot.sh). Regenerate the GRUB
# menu when any script changes.
GRUB_CHANGED=0
for grub_script in "$GRUB_SRC"/*; do
    [ -f "$grub_script" ] || continue
    dest="/etc/grub.d/$(basename "$grub_script")"
    cmp -s "$grub_script" "$dest" || GRUB_CHANGED=1
    sudo install -Dm755 "$grub_script" "$dest"
done

if [ "$GRUB_CHANGED" = 1 ]; then
    echo "==> grub.d scripts changed; regenerating GRUB menu"
    sudo grub-mkconfig -o /boot/grub/grub.cfg
fi

# Deploy every udev rules file from config/udev/rules.d/. These apply to the
# booted system only (for the initramfs, modprobe.d + modconf is the way -
# udev rules proved unreliable there). The current rule fires the power-profile
# switcher on AC plug/unplug.
UDEV_CHANGED=0
for rule in "$DIR/config/udev/rules.d/"*.rules; do
    [ -e "$rule" ] || continue
    dest="/etc/udev/rules.d/$(basename "$rule")"
    cmp -s "$rule" "$dest" || UDEV_CHANGED=1
    sudo install -Dm644 "$rule" "$dest"
done

if [ "$UDEV_CHANGED" = 1 ]; then
    echo "==> udev rules changed; reloading + re-triggering power_supply"
    sudo udevadm control --reload
    sudo udevadm trigger --subsystem-match=power_supply
fi

# power-profiles-daemon provides the D-Bus API build/power-profile.sh drives.
# Needs the package (system-packages.nix) to exist first.
if systemctl list-unit-files power-profiles-daemon.service >/dev/null 2>&1; then
    sudo systemctl enable --now power-profiles-daemon.service >/dev/null
    echo "==> power-profiles-daemon enabled"
else
    echo "warning: power-profiles-daemon not installed yet (run build/system-packages.sh); power profiles will not switch"
fi

# An earlier version used a custom udev rule + /dev/input/actkbd-kbd symlink.
# actkbd opens its device with fopen("a+"), which CREATES a regular file if
# the path is missing - so a bogus file can sit there and block the symlink,
# and udevadm trigger does not reliably re-create a symlink that was removed
# on an already-running box. Both are gone; clean up after that version.
sudo rm -f /dev/input/actkbd-kbd
sudo rm -f /etc/udev/rules.d/70-applespi-actkbd.rules
# The backlight boot floor moved from a udev rule to a modprobe.d install
# reroute (udev rules were not bundled/reliable inside the initramfs).
sudo rm -f /etc/udev/rules.d/10-kbd-backlight-boot.rules
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
echo "==> modprobe.d deployed; initramfs $( [ "$REBUILD_INITRAMFS" = 1 ] && echo 'rebuilt' || echo 'already current' )"
