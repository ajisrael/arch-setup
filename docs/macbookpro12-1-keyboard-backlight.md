# MacBookPro12,1 Keyboard Backlight Keys (F5/F6)

**Status:** researched 2026-08, fix drafted but not yet applied to
`config/hypr/hyprland.lua` or verified on archeus. Pick up here.

## Summary

No kernel driver or config change is needed. The keyboard-backlight keys are
broken purely because nothing in Hyprland reacts to them: the drivers already
loaded on archeus provide both the key events and the brightness control.

## Findings

- **`applespi`** (the SPI keyboard/trackpad driver, already loaded - it *is*
  the keyboard driver) maps F5/F6 to `KEY_KBDILLUMDOWN` / `KEY_KBDILLUMUP`
  in `drivers/input/keyboard/applespi.c:483-484`. To the desktop these are
  `XF86KbdBrightnessDown` / `XF86KbdBrightnessUp`. It also registers the
  `spi::kbd_backlight` LED class device (registration is unconditional,
  applespi.c:1767-1780).
- **`applesmc`** registers `smc::kbd_backlight` when the SMC has the `LKSB`
  key. On the 2015 13" MBP (12,1) the keyboard backlight is SMC-controlled;
  a CachyOS forum report for exactly this model confirms `smc::kbd_backlight`
  is the working path on a vanilla Arch kernel (and that a CachyOS-specific
  patch broke it there, a CachyOS-only regression).
- Kernel config: `CONFIG_KEYBOARD_APPLESPI=m`, `CONFIG_SENSORS_APPLESMC=m`,
  `CONFIG_LEDS_CLASS=y`. All present in Arch's default config, so the locally
  rebuilt kernel (built from the Arch packaging tree) has them too. Nothing to
  enable.
- Screen backlight keys work because `config/hypr/hyprland.lua:220-221` binds
  `XF86MonBrightnessUp/Down` to `brightnessctl`. There is **no**
  `XF86KbdBrightnessUp/Down` binding - that is the entire gap. `brightnessctl`
  is already installed.

## Verify on archeus before applying

```sh
brightnessctl -l | grep -i backlight   # which kbd LED exists?
brightnessctl -d smc::kbd_backlight set 100%
```

If `smc::kbd_backlight` does not exist, try `spi::kbd_backlight` and use that
name below. Confirm the key events with `wev` (press F5/F6, expect
`XF86KbdBrightnessDown` / `XF86KbdBrightnessUp`).

## Fix to apply later

Add next to the existing `XF86MonBrightness*` binds in
`config/hypr/hyprland.lua`:

```lua
hl.bind("XF86KbdBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -d smc::kbd_backlight set +5%"), { locked = true, repeating = true })
hl.bind("XF86KbdBrightnessDown", hl.dsp.exec_cmd("brightnessctl -d smc::kbd_backlight set 5%-"),  { locked = true, repeating = true })
```

## Alternatives considered

- `macbook-kbd-backlight` (juicecultus/macbook-kbd-backlight): a systemd
  service that maps the same keys to the `spi::kbd_backlight` LED via the
  upower D-Bus interface, with OSD support in DEs that subscribe to it.
  Useful where the desktop does not bind the keys; the `brightnessctl` binds
  above match what this setup already does for the screen backlight, so
  prefer them.

## References

- `drivers/input/keyboard/applespi.c` (mainline): F5/F6 translation
  (applespi_fn_codes), `spi::kbd_backlight` registration, SPI backlight
  command protocol (`0xB051`), EFI-variable save/restore
  (`KeyboardBacklightLevel`).
- `drivers/hwmon/applesmc.c` (mainline): `smc::kbd_backlight`, `LKSB` key.
- CachyOS forum, "Keyboard Backlight not working on macbook pro 12,1":
  <https://discuss.cachyos.org/t/keyboard-backlight-not-working-on-macbook-pro-12-1-with-cachyos-kernel/9181>
- juicecultus/macbook-kbd-backlight:
  <https://github.com/juicecultus/macbook-kbd-backlight>
