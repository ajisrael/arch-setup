# Omarchy feature review (what's worth adding here)

A deep scan of the locally cloned Omarchy repo (`~/examples/omarchy`, basecamp/omarchy)
compared against this build, and the resulting shopping list. Ordered exactly as the
analysis was presented: **Tier 1** (high value, low effort, fits the declarative model)
→ **Tier 2** (medium value, more effort) → **Tier 3** (interesting but optional / not a
fit). Each entry names the Omarchy source (`bin/omarchy-*`, `shell/`, `etc/`, `install/`,
`docs/`) so the reference stays greppable.

## Framing: Omarchy is a distro layer, not a dotfile repo

Omarchy is a full opinionated Arch-based distribution built around Hyprland + a
Quickshell QML desktop. Two things dominate the repo:

- `shell/` — one long-running Quickshell process replaces the usual stack of separate
  Wayland tools (waybar, mako, wofi/rofi, swaylock, polkit-gnome, hypridle) with a
  single QML instance hosting bar, panels, overlays, menus and services as plugins.
- `bin/omarchy-*` — 403 standalone scripts (theme system, update flow, hardware
  detection, install/remove bundles, system controls) dispatched by the `omarchy` CLI.

This build is a minimal Hyprland + home-manager setup on a MacBook Pro 12,1
(i7-5557U, 16 GB, i915, Broadcom wifi, tailscale). Most of Omarchy's *value* transfers
as **reusable scripts and ideas**, not the shell itself. The shell architecture is
deliberately not on the table (see Tier 3) — this list is what plugs into the existing
waybar/hyprlock/mako/wofi stack.

## Tier 1 — High value, low effort, fits the declarative model

1. **Idle → lock pipeline (lock on sleep + timeout).** `hypridle` is installed but the
   config is commented out (`config/hypr/hyprland.lua:39` — "once a hypridle.conf
   exists"). Omarchy stages idle: screensaver → lock → suspend, with lock-before-sleep
   (`shell/plugins/services/idle/Service.qml`, `bin/omarchy-system-sleep-lock`, and
   `etc/systemd/logind.conf.d/` `InhibitDelayMaxSec=15` so the lock has time to secure
   the session before sleep). **Implemented here** as `config/hypr/hypridle.conf`
   (lock at 5 min, DPMS off at 5:30, suspend at 15 min; lock fires before any suspend
   including lid-close). See bottom of this doc for apply status.

2. **AC/battery power-profile autoswitch.** `power-profiles-daemon` is not installed.
   Omarchy's `bin/omarchy-powerprofiles-set` reads AC/battery via
   `busctl UPower OnBattery`, persists the active profile per state to
   `~/.local/state/omarchy/powerprofiles/{ac,battery}`, and `-init` applies it at boot.
   Real battery win on a 2015 MBP: add `power-profiles-daemon` to
   `system-packages.nix`, plus a UPower hook or `on-battery`/`on-ac` handler.

3. **Audio sink switching + recovery.** Only volume/mute binds exist today
   (`hyprland.lua` XF86 block). `bin/omarchy-audio-output-switch` (wpctl sink cycling)
   and `bin/omarchy-restart-audio` (225 lines: KILL-forces wedged
   pipewire/wireplumber, recovers stuck USB audio devices) are direct steals. A
   Super+A sink picker plus a restart-audio keybind covers the daily audio annoyances.

4. **Screenshot/recording suite.** Only `grim -g "$(slurp)" | swappy` is bound.
   Omarchy's `bin/omarchy-capture-screenshot` (region/window/fullscreen + copy/save,
   frozen-screen picker, `cursor:no_hardware_cursors` workaround),
   `bin/omarchy-capture-screenrecording` (wf-recorder, +webcam variants) and
   `bin/omarchy-capture-text` (OCR) round it out. `wf-recorder` is not installed.

5. **Nightlight toggle.** `hyprsunset` (or wlsunset) is absent. Omarchy stages
   4000K/6500K via `shell/plugins/services/nightlight/Service.qml` +
   `bin/omarchy-toggle-nightlight`. A toggle keybind is a small, pleasant add.

6. **Wireless + watcher tuning.** Three `etc/` drop-ins worth copying for Broadcom
   wifi and editor/agent watchers:
   - `etc/NetworkManager/conf.d/omarchy-wifi-powersave.conf` — `wifi.powersave = 2`
     (firmware drops links when the radio naps).
   - `etc/modprobe.d/omarchy-usb-autosuspend.conf` — `options usbcore autosuspend=-1`.
   - `etc/sysctl.d/90-omarchy-file-watchers.conf` — `fs.inotify.max_user_watches=524288`.
   Also `systemd-oomd` with the tuned `etc/systemd/oomd.conf.d/` limits.

7. **Snapshot-before-update workflow.** `build/snapshot.sh` exists but is manual.
   Omarchy's `bin/omarchy-update` (see `docs/update-process.md`) runs: free-space check
   → **snapshot** → stay-awake inhibitor → pacman → migrations → hooks → restart
   markers. A thin `build/update.sh` wrapper (`snapshot.sh && pacman -Syu` + restart
   prompt) plus an ALPM hook to snapshot on upgrade closes the loop in the spirit of
   the btrfs rollback setup.

## Tier 2 — Medium value, more effort

8. **Cross-app theme system.** Omarchy's signature. `themes/<name>/colors.toml` feeds
   `bin/omarchy-theme-set` → `bin/omarchy-theme-set-templates` (17 templates: kitty,
   foot, tmux, wofi-equivalents, hyprland.lua, etc.; see `docs/theming.md`). The Tokyo
   Night palette is currently hardcoded in 6+ repo files (hyprland.lua, kitty.conf,
   waybar, mako, tmux, wofi, bash prompt). A lightweight version — one `palette` file +
   an `apply-theme.sh` that regenerates the repo configs — would restyle the whole
   desktop together and de-duplicate the hex values.

9. **External monitor / clamshell handling.** `bin/omarchy-hyprland-monitor-*`
   (clamshell state machine: lid + DPMS + scale; `-recover-internal-monitor` systemd
   unit) and `bin/omarchy-brightness-display-ddc` (external panel brightness over DDC).
   Relevant when docking.

10. **Launch-or-focus.** `bin/omarchy-launch-or-focus` (hyprctl clients regex → focus
    existing window, else launch) plus `-tui`/`-webapp` variants. A great Super+<key>
    ergonomic; easy to port as one function.

11. **Window toggles.** `bin/omarchy-hyprland-window-*`: gaps-toggle,
    transparency-toggle, tiled-fullscreen-toggle, single-square-aspect-toggle,
    workspace-layout-toggle, `pop` (float-focus), close-all, width. Cheap, fun
    Hyprland binds.

12. **Wi-Fi QR + status.** `bin/omarchy-network-qr` (qrencode) — share wifi creds with
    a phone — plus `bin/omarchy-network-status`. `qrencode` is not installed.

13. **Taildrop send/receive.** tailscale is up (`tailscale0`) but unused for file
    transfer. `bin/omarchy-tailscale-send` (MagicDNS short names) and
    `bin/omarchy-tailscale-receive` (hardlink-rename so files appear atomically in
    `~/Downloads`) are ~150 lines total.

14. **Webapp launcher.** `bin/omarchy-webapp-*` + `bin/omarchy-launch-webapp` —
    Chromium PWA windows with custom icons; fits the google-chrome setup.

15. **Keybinding cheatsheet.** `bin/omarchy-menu-keybindings` renders the Hyprland
    binds. A repo script that greps `hyprland.lua` into a cheatsheet aids learning/UX.

16. **zram + hibernation.** LUKS root + 16 GB. Omarchy's zram-generator +
    `tmpfiles.d` zswap-disable + tuned VM sysctls, and `bin/omarchy-hibernation-setup`/
    `-remove` (LUKS-aware). Worth evaluating; hibernation on this MBP is finicky —
    test on a snapshot first.

17. **Hardware-detection pattern.** `bin/omarchy-hw-*` + `install/hardware/` is mostly
    model-specific, but the *pattern* (DMI/sysfs gates before applying a fix) is the
    right framework for the kernel-patch docs in this repo. Notably Omarchy's
    `install/hardware/apple/fix-spi-keyboard.sh` + `macbook12-spi-driver-dkms` solve the
    same SPI-keyboard problem this repo patches the kernel for — worth reading to
    compare approaches; `fix-suspend-nvme.sh` targets the same suspend family.

## Tier 3 — Interesting but optional / not a fit

- **Agent usage panel** (`shell/plugins/agents/`, `bin/omarchy-agent-usage-*`): per-
  provider usage stats (Claude/Codex/Fireworks rate limits, tokens/day) via collector
  scripts → watched JSON → panel. The *data flow* is a clean idea to reimplement as a
  waybar module; the panel itself is Quickshell-bound.
- **Event hook system** (`config/omarchy/hooks/*.d`: post-update, post-boot, theme-set)
  — small; could slot into `build/system-config.sh`.
- **Migrations** (`migrations/`, `bin/omarchy-migrate`): one-time repair scripts with
  per-user markers. The declarative home-manager + `system-config.sh` model already
  covers this role; skip.
- **Mise toolchain** (`install/user/mise.sh`): version-managed AI CLIs (claude, codex,
  opencode, ...). Overkill unless dropping the pacman `opencode` pin.
- **First-run / welcome flow** (`install/user/first-run/`): toast-guided onboarding;
  `mentor-notes/` already serves this purpose here.
- **Speaker tuning** (`docs/AUDIO-TUNING.md`, lsp-plugins-lv2 filter chains): hardware-
  matched DSP. Check whether a 12,1 tuning exists; fun but low priority.
- **Full Quickshell shell** (`shell/`): replaces waybar/mako/wofi/hyprlock/polkit with
  one QML process. Architecturally cool but a rewrite of the whole desktop and the most
  opinionated, volatile part of the repo. `hyprpanel` is the maintained middle ground
  if part of this is ever wanted.

## If you only do a few

1. `hypridle.conf` — lock on sleep + timeout (implemented, see below)
2. power-profiles-daemon AC/battery autoswitch
3. wifi powersave off + inotify watchers (sysctl)
4. `build/update.sh` = snapshot + pacman + restart-aware
5. audio sink switch + `restart-audio`

## Apply status

| Item | Status |
| ---- | ------ |
| #1 idle → lock pipeline | Implemented (`config/hypr/hypridle.conf`, wired into `home.nix` + autostart). Pending user apply via `./rebuild.sh`. |
| #2 power profiles | Implemented (`build/power-profile.sh` + `config/udev/rules.d/90-power-profile.rules` + `power-profiles-daemon` in `system-packages.nix` + autostart + `system-config.sh` deploy). Pending package install + apply. |
| #3 audio switching | Implemented (`build/audio-sink-cycle.sh` sink cycling + `build/restart-audio.sh` recovery; Super+A / Super+Shift+A binds). |
| #4 capture suite | Not started |
| #5 nightlight | Not started |
| #6 wireless/watcher tuning | Not started |
| #7 snapshot-update flow | Not started |
| #8–17 | Not started |
| Tier 3 | Evaluated, no action planned |
