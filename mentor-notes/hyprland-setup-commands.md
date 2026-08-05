# Hyprland Setup - Command Reference

Commands run during the mentoring session that set up Hyprland on the
MacBookPro12,1 Arch box. Each entry explains what the command does, the
arguments used, and why it was part of the setup. Companion to
`hyprland-setup-<date>.md` (the session notes).

## Checkpoint 1 - Install and verify the graphics stack

| Command | What it does | Why we ran it |
|---|---|---|
| `sudo pacman -S hyprland` | Installs Hyprland from the official Arch repos. `-S` = sync/install, `sudo` because pacman mutates the system. | Hyprland is packaged in `extra`; upstream recommends the distro package over `-git` builds. |
| `sudo pacman -S kitty` | Installs the kitty terminal emulator. | Hyprland ships no terminal; you need one to do anything inside the session. |
| `sudo pacman -S polkit` | Installs the polkit authorization framework. | ArchWiki: Hyprland will fail to start without `polkit` installed or `seatd.service` running. Neither existed on this fresh install. |
| `pacman -Q mesa` | Queries whether the `mesa` package is installed. `-Q` = query, exact name. | Mesa is the userspace OpenGL implementation Hyprland renders through. `-Qs` (search) is the looser variant; `-Q` requires the exact name. |
| `lsmod \| grep i915` | Lists loaded kernel modules, filtering for the Intel DRM driver. | Verifies the kernel-side GPU driver (`i915`) is actually loaded - without it mesa has no hardware to talk to. |
| `lspci -k` (or `lspci -k \| grep -A2 VGA`) | Lists PCI devices; `-k` adds the "Kernel driver in use" line for each. `-A2` = show 2 lines after the match. | Confirms which driver owns the GPU. Output reads `Kernel driver in use: i915`. The driver line sits *below* the device line, so `grep -A2` (not plain `grep`) is needed to see it. |
| `ls /dev/dri/` | Lists the DRM device nodes (`cardN`, `renderDNNN`). | `card*` = display controllers, `renderD128` = the render node that accelerated OpenGL uses. Their existence means the kernel exposed the GPU. |
| `ls -l /dev/dri/by-path/` | Lists symlinks mapping each DRM device to its PCI address. | Proves which GPU each card actually is. Here `pci-0000:00:02.0-card -> card1` confirms the Intel iGPU is the only DRM device. |
| `ls /sys/class/drm/` | Lists DRM devices, each card's connectors, and the subsystem version. | Confirms card identity and that the laptop panel (`card1-eDP-1`) plus outputs are registered. |

## Checkpoint 2 - Launch Hyprland

| Command | What it does | Why we ran it |
|---|---|---|
| `start-hyprland` | Launches Hyprland from the TTY. | The current recommended launcher (a wrapper with crash recovery and safe mode); `Hyprland` directly is no longer recommended. |

## Checkpoint 3 - Install Nix (standalone, multi-user, daemon)

The Arch `nix` package (2.35.x) was reworked: it is **socket-activated** and
manages accounts via **systemd-sysusers**, NOT the old `nix-users` group that
the (stale) ArchWiki section describes. Verified 2026-08-04 against nix
2.35.1-3.

| Command | What it does | Why we ran it |
|---|---|---|
| `sudo pacman -S nix` | Installs Nix from `extra`. | Arch's official packaging of the Nix package manager. Prints no install notes - normal. |
| `getent group nixbld` | Looks up the `nixbld` group in the system databases. | Confirms the sysusers config from the package was applied. Group + `nixbld01-10` users already existed from install. |
| `sudo systemd-tmpfiles --create` | Applies `tmpfiles.d` configs to create the package's runtime dirs. | Creates `/nix/var/nix/daemon-socket` and `/nix/var/nix/builds` (normally done at boot). Must run BEFORE enabling the socket - the socket unit has `ConditionPathIsReadWrite=/nix/var/nix/daemon-socket`. |
| `sudo systemctl enable --now nix-daemon.socket` | Enables + starts the socket-activated daemon. | Correct modern way. The `.service` should NOT be enabled: systemd refuses to listen on a socket whose service is already active ("Socket service already active, refusing"). Fix was `systemctl stop` + `disable` the `.service`. |
| `sudoedit /etc/nix/nix.conf` | Edit the system Nix config. | Add `experimental-features = nix-command flakes` - the Arch package ships `nix.conf` with only `build-users-group = nixbld` and no experimental features, so `nix run` fails with "experimental Nix feature 'nix-command' is disabled". |
| `sudo install -d -o root -g root -m 1775 /nix/store` | Create the store dir with proper ownership/mode. | The package's tmpfiles config deliberately does NOT create `/nix/store`; without it `nix run` errors "opening file /nix/store: No such file or directory". Mode 1775 (sticky, root:root) matches multi-user installs. |
| `nix run nixpkgs#hello` | Smoke test: fetch + run hello from the binary cache. | Prints "Hello, world!" - confirms the daemon, store, and user access all work end to end. |

Gotchas learned (worth documenting for the next rebuild):
- The old ArchWiki flow (`usermod -aG nix-users`) is stale - this package has
  NO `nix-users` group and NO `trusted-users` restriction, so any local user
  can use the daemon.
- `profile.d/nix-daemon.sh` sets PATH/XDG_DATA_DIRS/SSL certs (no NIX_PATH, but
  flake mode doesn't need it). Desktop integration for Nix-installed apps comes
  from the XDG_DATA_DIRS line already present.
- Order matters: tmpfiles -> socket enable -> store dir -> smoke test.

## Still to come (checkpoints 4-5)

- Scaffold `flake.nix` + `home.nix` in this repo (homeConfigurations."archeus").
- Add a session/desktop entry so Hyprland survives reboots and (later) shows up in SDDM's session picker.
- Install the welcome-screen components (audio, portal, bar, notifications, etc.) - split between pacman (system packages) and home-manager (config files).
