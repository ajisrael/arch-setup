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

## Checkpoint 4 - Bootstrap home-manager (standalone + flakes)

| Command | What it does | Why we ran it |
|---|---|---|
| `git clone <remote> ~/arch-setup` | Get the repo onto the box. | Home-manager needs the flake on the machine it targets. Repo already had flake.nix + home.nix synced. |
| `nix profile add github:nix-community/home-manager#home-manager` | Installs the home-manager CLI into the user profile. | Bootstrap step to get a `home-manager` binary. (`install` is a deprecated alias for `add` in Nix 2.35.) |
| `source /etc/profile.d/nix-daemon.sh` | Re-applies PATH/XDG wiring for the current shell. | The profile.d script only runs in login shells; `home-manager` was not found in the existing shell. |
| `home-manager build --flake .#archeus` | Dry run: evaluates + builds the config into `./result`. | Validates before applying; touches nothing in `~`. First run fetches inputs + writes `flake.lock`. |
| `home-manager switch --flake .#archeus` | Applies the config: installs packages, links dotfiles, creates the generation profile. | The apply step. |
| `nix profile remove home-manager` | Removes the bootstrap CLI from the profile. | It collided with the generation's `home-manager-path` package (both provide `bin/home-manager` at priority 5 -> "An existing package already provides the following file"). |
| `nix run github:nix-community/home-manager#home-manager -- switch --flake .#archeus` | Runs the first switch straight from the flake input, not the profile. | Canonical first-switch for standalone setups. The CLI and flake.lock were at the same commit, so no version mismatch. Afterwards the generation self-hosts `home-manager` (via `~/.local/state/nix/profile/bin`). |

Flake scaffold created: `flake.nix` (inputs nixpkgs-unstable + home-manager master,
`homeConfigurations.archeus`, plus a `packages.x86_64-linux.home-manager` output
that bootstrap.sh uses to run a version-matched CLI), `home.nix` (username,
homeDirectory, stateVersion 26.05, `programs.home-manager.enable`,
`programs.git`, `pkgs.hello`), `rebuild.sh`, `bootstrap.sh` (encodes the
Checkpoint 3 gotchas), `.gitignore` (result, result-*), `AGENTS.md`.

Git identity gotchas:
- Home-manager master renamed the git options: `programs.git.userName` ->
  `programs.git.settings.user.name`, same for `userEmail`. The old names emit
  deprecation traces.
- `programs.git` writes `~/.config/git/config` + a `~/.gitignore` include wire-up.

Repo hygiene:
- Commit `flake.lock` (pins input revisions - the reproducibility story).
- Do NOT commit `result` (symlink into /nix/store).

## Checkpoint 5 - Install welcome-screen packages (batches 1-2)

Batch 1 (audio):
| Command | What it does | Why we ran it |
|---|---|---|
| `sudo pacman -S pipewire wireplumber pipewire-pulse pipewire-audio` | Installs the PipeWire audio server + session manager + PulseAudio compat. | The modern Wayland audio stack; pulse is legacy, jack only for pro audio. |
| `systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber` | Starts PipeWire as user services. | PipeWire is per-user; sockets give on-demand start. |
| `sudo pacman -S alsa-utils` | Installs ALSA CLI tools (`aplay`, `alsamixer`). | Diagnosis only - `aplay` wasn't found and PipeWire doesn't depend on it. |
| `aplay -l` | Lists playback hardware via ALSA. | Confirmed the MacBook's Cirrus HDA card: `card 1: CS4208 Analog` (snd_hda_intel). |
| `wpctl status` | Shows the PipeWire session graph (devices/sinks/sources). | Confirmed `Built-in Audio Analog Stereo` is the default sink (vol 0.40). RTKit warnings in output are benign. |

Batch 2 (desktop components) - `sudo pacman -S ...`:
`hyprpaper hyprlock hypridle hyprpolkitagent waybar mako wofi wl-clipboard
cliphist grim slurp swappy xdg-desktop-portal xdg-desktop-portal-hyprland
brightnessctl thunar less`
- At the `jack` provider prompt chose `pipewire-jack` (runs the jack API
  through the existing PipeWire instead of a separate jack2 server).
- Alternatives weighed before installing (user picked all recommended):
  wallpaper hyprpaper>swww>swaybg; bar waybar>hyprpanel>eww; notifications
  mako>swaync; launcher wofi>fuzzel>rofi-wayland; file manager
  thunar>pcmanfm>yazi; screenshots grim+slurp+swappy>hyprshot; auth agent
  hyprpolkitagent>polkit-kde-agent; volume CLI wpctl only (no pamixer - waybar
  uses wpctl natively).

## Checkpoint 6 - Welcome-screen configs

Config files live as plain files in this repo under `config/` (mirroring XDG
paths), symlinked into `~/.config` via `home.file` +
`mkOutOfStoreSymlink` - live-editable in place, no re-switch needed to tweak:
- `config/hypr/hyprland.lua` - trimmed from the shipped default template
  (`/usr/share/hypr/hyprland.lua` pasted by the user; the authoritative v0.55+
  Lua DSL). Terminal kitty, fileManager thunar, menu `wofi --show drun`;
  autostart block (`hyprland.start`) launches hyprpaper, waybar, mako,
  hyprpolkitagent, `wl-paste --watch cliphist store`; hypridle commented out
  until a hypridle.conf exists. Added binds: Super+L -> hyprlock,
  Super+Shift+S -> `grim -g "$(slurp)" - | swappy -f -` (MacBooks have no
  Print/PrintScreen key, so the screenshot bind lives on Super+Shift+S; that
  meant dropping the template's move-to-scratchpad bind - Super+S toggle
  stays). Brightness keys use
  plain `brightnessctl set ±5%` (template's `-e4 -n2` flags are not standard).
  Removed playerctl media-key binds (playerctl not installed).
  touchpad natural_scroll = true (MacBook user).
- `config/kitty/kitty.conf`, `config/mako/config`, `config/wofi/config`,
  `config/waybar/config.jsonc` + `style.css`, `config/hypr/hyprlock.conf`,
  `config/hypr/hyprpaper.conf`.
- Fonts prerequisite (pacman): `ttf-jetbrains-mono-nerd noto-fonts`.
- **hyprlock gotcha**: no `input-field` block = screen renders but is
  undeletable (nothing to type into, keyboard dead). Rescue from another TTY
  (`Ctrl+Alt+F2`, log in, `pkill hyprlock`, back on `Ctrl+Alt+F1`). Config
  always needs an `input-field` block.
- Wallpaper image goes at `config/wallpapers/current.jpg` (referenced by both
  hyprpaper.conf and hyprlock.conf).

Verify on box: waybar top bar, wallpaper, Super+Q kitty, Super+R wofi,
Super+L hyprlock, Super+Shift+S screenshot, Super+M exit. Restart Hyprland
fully after the switch - autostarts only fire on start.

## WRAP-UP checkpoints (after configs)

- Declarative pacman package list as a nix value in flake.nix +
  `system-packages.sh` (`sudo pacman -S --needed $(nix eval .#systemPackages --raw)`)
  folded into rebuild.sh - gives the "brew-under-nix" single-source-of-truth
  without nix running pacman (home-manager is user-level; no pacman module).
  Declarative, not reproducible (versions float) - true pinning needs cache
  archiving. Boot layer stays in docs/arch-setup-mac.md.
- Session/desktop entry so Hyprland survives reboots and (later) shows up in
  SDDM's session picker.
