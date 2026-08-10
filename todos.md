# System Setup TODOS:

## Hyprland

- [x] Battery life added to waybar
- [x] Labels added to waybar
- [x] Backgrounds added
- [x] Theme gradients and waybar for tokyo night
- [ ] Set dark mode default for apps like file explorer

- [ ] Get waybar workspace selection working via mouse click

## Terminal

- [x] auto complete suggestions
- [x] tokyo night color theme
- [x] update bash prompt:
    - [x] full path
    - [x] Linux icon would be cool
    - [x] python, java, and node environments
    - [x] git branch and status with colors
    - [x] current time for when command was run and how long previous command took
    - [x] colored in theme with rest of system
    - Note: similar to current macos configuration would be ideal
- [x] add custom tmux configurations

## Software

- [x] web browser (Chrome)
- [x] neovim

## System

- [x] Add script to snapshot system and restore from a snapshot.
    - Note: just need to be comfortable with snapshot and restore in case something breaks

## Omarchy backlog (see docs/omarchy-features-review.md)

Tier 1 - high value, low effort:

- [x] Idle -> lock pipeline: hypridle lock on sleep + staged timeout (lock 5m -> dpms 5:30 -> suspend 15m). Pending `./rebuild.sh`.
- [x] AC/battery power-profile autoswitch (power-profiles-daemon): build/power-profile.sh + udev rule + autostart. Pending package install + system-config.sh.
- [x] Audio sink switching + restart-audio recovery: build/audio-sink-cycle.sh (Super+A) + build/restart-audio.sh (Super+Shift+A).
- [ ] Screenshot/recording suite (region/window/fullscreen, wf-recorder, OCR)
- [ ] Nightlight toggle (hyprsunset/wlsunset)
- [ ] Wireless + watcher tuning (wifi powersave off, inotify watchers, oomd)
- [ ] Snapshot-before-update workflow (build/update.sh + ALPM hook)

Tier 2 - medium value, more effort:

- [ ] Cross-app theme system (palette -> generated configs)
- [ ] External monitor / clamshell handling
- [ ] Launch-or-focus helper
- [ ] Window toggles (gaps / transparency / fullscreen / aspect / layout / pop)
- [ ] Wi-Fi QR + status
- [ ] Taildrop send/receive
- [ ] Webapp launcher
- [ ] Keybinding cheatsheet
- [ ] zram + hibernation (LUKS-aware)
- [ ] Hardware-detection pattern (DMI/sysfs-gated fixes)
