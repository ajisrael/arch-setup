# MacBookPro12,1 Keyboard Backlight Keys (F5/F6)

**Status:** solved with a system-level `actkbd` service (see "Fix"), committed
to the repo as `config/actkbd/`. Not yet applied/verified on archeus.

## Summary

The F5/F6 keyboard-backlight keys did not work in the base tty1 (they only
work inside Hyprland after a binding is added). The fix is a **system-level**
`actkbd` service that steps `smc::kbd_backlight` from the raw evdev events.
Because it reads evdev globally, it works at tty1, at the login prompt, and
inside Hyprland alike - no per-desktop binding needed.

## Why the brightness keys only work inside Hyprland

On this MacBook all top-row function keys are routed through the SPI keyboard
controller (`applespi`): F1/F2 -> `KEY_BRIGHTNESSDOWN`/`KEY_BRIGHTNESSUP`
(applespi.c:479-480), F5/F6 -> `KEY_KBDILLUMDOWN`/`KEY_KBDILLUMUP`
(applespi.c:483-484). Every one of them is a plain evdev event with no
in-kernel consumer - so at a bare tty1 nothing reacts to any of them. Inside
Hyprland the screen keys work only because `config/hypr/hyprland.lua` binds
`XF86MonBrightnessUp/Down` to `brightnessctl` (lines 220-221); nothing binds
the keyboard keys. (The kernel's ACPI-video notify handler that makes screen
keys work at the console on other laptops does not fire on this hardware.)

## Findings

- **`applespi`** maps F5/F6 to keycodes 229/230 and registers the `spi::kbd_backlight`
  LED class device (applespi.c:1687, name `Apple SPI Keyboard`, phys
  `applespi/input0`).
- **`applesmc`** registers `smc::kbd_backlight` (SMC key `LKSB`); on the 2015
  13" MBP (12,1) this is the working control path (CachyOS forum report for
  exactly this model on a vanilla Arch kernel).
- **No `brightness_get`:** applesmc implements only `brightness_set`
  (applesmc.c:1069-1072), so the sysfs `brightness` file reflects the last
  value written through the LED core, not the hardware state. Relative
  brightnessctl steps therefore misbehave after boot; `kbd-backlight-step`
  tracks state via the LED core cache instead.
- Kernel config: `CONFIG_KEYBOARD_APPLESPI=m`, `CONFIG_SENSORS_APPLESMC=m`,
  `CONFIG_LEDS_CLASS=y`. Present in Arch's default config, so the locally
  rebuilt kernel has them too. Nothing to enable.

## Fix (in this repo)

Files under `config/actkbd/`, deployed to `/etc` by `build/system-config.sh`:

- `actkbd.conf` - binds 229 (`F5`, down) and 230 (`F6`, up) to
  `kbd-backlight-step`.
- `kbd-backlight-step` - steps `smc::kbd_backlight` by ~10% via sysfs.
- `actkbd.service` - systemd unit pointing at the stable device symlink. No
  `[Install]` section: it is started by udev (`SYSTEMD_WANTS`) when the
  keyboard device appears, so it can never race the device node.
- `70-applespi-actkbd.rules` - udev rule creating `/dev/input/actkbd-kbd`
  (a symlink to the applespi keyboard event node, so the unit does not depend
  on boot-order-dependent `/dev/input/eventN`) and starting the service.

The Hyprland `XF86KbdBrightness*` binds previously drafted here are dropped:
with actkbd reading the device globally, Hyprland binds would double-step.

## Setup on archeus

```sh
# 1. AUR helper (one-time) - paru recommended, see docs/arch-setup-mac.md
sudo pacman -S --needed base-devel git
git clone https://aur.archlinux.org/paru.git ~/build/paru && cd ~/build/paru && makepkg -si

# 2. System packages (actkbd, brightnessctl) from the tracked lists
./build/system-packages.sh

# 3. Deploy config + unit + udev rule (starts the service, device-driven)
./build/system-config.sh
```

`system-config.sh` also removes a leftover bogus `/dev/input/actkbd-kbd`
regular file (see the script comments for the fopen race that creates it) and
waits for udev (`udevadm settle`) before starting the service.

Verify:

```sh
systemctl status actkbd.service
sudo actkbd -n -s -d /dev/input/actkbd-kbd   # press F5/F6, expect keycodes 229/230
cat /sys/class/leds/smc::kbd_backlight/brightness   # changes on F5/F6
```

Caveat: after boot the LED core cache starts at 0, so the first F6 press sets
~10% regardless of hardware state; keep pressing to raise it.

## References

- `drivers/input/keyboard/applespi.c` (mainline): F5/F6 translation, input
  device name/phys, `spi::kbd_backlight` registration.
- `drivers/hwmon/applesmc.c` (mainline): `smc::kbd_backlight`, `LKSB` key,
  `brightness_set`-only LED classdev.
- `drivers/acpi/acpi_video.c` (mainline): native screen-brightness notify
  handling - does NOT fire on this hardware, which is why no top-row key works
  at a bare console.
- `include/uapi/linux/input-event-codes.h`: `KEY_KBDILLUMDOWN=229`,
  `KEY_KBDILLUMUP=230`.
- actkbd upstream README: <https://github.com/thkala/actkbd> (config format,
  `-n -s` keycode mode). AUR package: <https://aur.archlinux.org/packages/actkbd>.
- CachyOS forum, "Keyboard Backlight not working on macbook pro 12,1":
  <https://discuss.cachyos.org/t/keyboard-backlight-not-working-on-macbook-pro-12-1-with-cachyos-kernel/9181>
