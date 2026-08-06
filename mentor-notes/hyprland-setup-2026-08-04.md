# Hyprland on MacBookPro12,1 (Arch) setup

Started 2026-08-04. Mentoring session - guidance, not solved-for-you.

Hardware: MacBookPro12,1 (2015 13" MBP), Intel Broadwell iGPU (HD 6100), fresh
manual Arch install per docs/arch-setup-mac.md (LUKS+Btrfs, NetworkManager with
iwd backend, no DE, no mesa yet).

### Hardware compatibility (verified)
- Hyprland requires OpenGL 3.2+ / OpenGL ES 3.0+; Intel Iris 6100 (Broadwell-U
  GT3, 48 EU - NOT HD 6100, corrected by user's lspci) provides GL 4.4 via
  Mesa -> fully supported, no NVIDIA-style workarounds needed.
- Verified i915 DRM driver loaded (lsmod), renderD128 present, /dev/dri exists.
- Wrinkle: DRM card is card1, not card0 - some other device holds card0.
  Investigation pending via /dev/dri/by-path/. Shouldn't matter for Hyprland
  (aquamarine picks the device with a connector) but worth confirming.
- Source: Hyprland wiki Installation page; Intel spec table (Broadwell GL 4.4).

### DRM investigation resolved - benign
- /dev/dri/by-path shows ONE DRM device: pci-0000:00:02.0 (the Intel iGPU) ->
  card1 + renderD128. /sys/class/drm shows only card1 + its connectors
  (eDP-1/DP-1/DP-2/HDMI-A-1/HDMI-A-2). No second GPU exists. card0 was a
  transient early-boot framebuffer (simpledrm/efifb) replaced when i915 bound.
  The card1-vs-card0 numbering is cosmetic.

### Commands doc
- mentor-notes/hyprland-setup-commands.md tracks every command run so far with
  what it does / args / why.

### Nix-on-Arch discussion (OPEN)
- User already runs nix-darwin + home-manager on macOS (that repo is pinned
  to 26.05 branches for x86_64-darwin). Question: extend declarative mgmt to
  the Arch box for "rebuild if the machine dies".
- User's macOS model: tier 1 Nix / tier 2 Homebrew / tier 3 curl-native; config
  files live as plain files in a home/ tree symlinked via home.file +
  home.activation (mkOutOfStoreSymlink for live editability).
- Leaning: standalone nix + home-manager on Arch for CONFIG FILES + user dev
  tools (reuse home.nix patterns); pacman keeps system + desktop packages
  (systemd/DBus integration, AUR, rolling). NixOS rejected as too costly:
  would require porting the whole MacBookPro12,1 keyboard stack (acpi_call,
  applespi SPI+PIO, kernel patch, GRUB+LUKS) and forfeits Arch/AUR.
- Timing: leaning NOW because ~8 new config files (hyprland.lua, kitty.conf,
  waybar, mako, ...) are about to be created - declaratize them from day one
  rather than retrofit later.
- Open: user's call on path + timing. Welcome-screen component list is the
  concrete first consumer of the decision.

### Nix-on-Arch DECIDED: Path 1, now (2026-08-04)
- Arch-native system + standalone home-manager. pacman = system + desktop
  packages; nix + home-manager = config files + user dev tools.
- REPO: user chose to keep the Linux Nix config in THIS arch-setup repo as a
  clean slate; evaluate merging with the macOS config only after the setup is
  complete and real overlap is visible.
- Open sub-decisions: nixpkgs/home-manager branch (26.05 stable vs unstable
  for herdr), hostname for homeConfigurations.

### Nix INSTALLED and working (2026-08-04, nix 2.35.1-3)
- The Arch package is MODERN and differs from the (stale) ArchWiki section:
  socket-activated daemon + systemd-sysusers accounts. NO `nix-users` group
  exists; no `trusted-users` restriction - any local user can use the daemon.
- Full working sequence (detail in commands doc):
  1. pacman -S nix (no install notes printed - normal)
  2. systemd-tmpfiles --create (creates /nix/var/nix/daemon-socket + builds)
  3. systemctl enable --now nix-daemon.socket  (NOT the .service - see gotcha)
  4. sudoedit /etc/nix/nix.conf: add experimental-features = nix-command flakes
  5. install -d -o root -g root -m 1775 /nix/store  (package doesn't create it)
  6. nix run nixpkgs#hello -> "Hello, world!" (smoke test passed)
- Gotchas hit along the way (all resolved):
  - `usermod -aG nix-users` fails: no such group (package uses sysusers, nixbld
    only). nixbld group + nixbld01-10 created at install, confirmed via getent.
  - Enabling BOTH nix-daemon.service and .socket: systemd refuses
    "Socket service nix-daemon.service already active, refusing" -> stopped +
    disabled the .service, socket-only.
  - No experimental features -> nix run error; fixed via /etc/nix/nix.conf.
  - /nix/store missing -> tmpfiles only makes /nix/var/nix/*, store created
    manually with mode 1775 root:root.
- profile.d/nix-daemon.sh handles PATH, XDG_DATA_DIRS (desktop integration for
  Nix apps), NIX_SSL_CERT_FILE. No NIX_PATH needed in flake mode.

### NEXT: scaffold flake.nix + home.nix in this repo
- Model: mirror the macOS flake shape (inputs nixpkgs + home-manager, output
  homeConfigurations."archeus" = homeManagerConfiguration).
- Branch decision still pending (26.05 stable vs unstable for herdr).
- home.nix starts minimal (platform split linux vs darwin), accretes the
  welcome-screen configs (hyprland, kitty, waybar, mako, wofi, ...) as they're
  created.

### Checkpoint 4 DONE: home-manager live on archeus (2026-08-04)
- Branch decision: nixpkgs-unstable + home-manager master (freshest Hyprland
  ecosystem; herdr is only on master). homeConfigurations named "archeus".
- flake.nix + home.nix scaffolded in this repo; rebuild.sh + bootstrap.sh
  (encodes all Checkpoint 3 gotchas) + AGENTS.md + .gitignore added.
- Bootstrap path: `nix profile add` home-manager CLI -> hit the classic clash
  (generation's home-manager-path vs profile CLI, both bin/home-manager prio 5)
  -> removed profile CLI -> first switch via `nix run github:...#home-manager`.
  Generation now self-hosts home-manager on PATH.
- Repo convention (matches user's macOS convention): user ALWAYS runs
  ./rebuild.sh themselves; agents validate with `nix flake check --no-build`.
- home-manager master renamed git options: programs.git.settings.user.{name,
  email} (userName/userEmail deprecated, emit traces).
- User explicitly asked: no hardcoded ~/dotfiles references in this repo -
  scrubbed from AGENTS.md/bootstrap.sh/notes. Repo is self-contained.
- Repo hygiene: commit flake.lock, ignore result. Git identity now declarative
  via programs.git so committing on the box works after home-manager switch.

### NEXT: Checkpoint 5 - welcome-screen components
- Split: pacman gets system/desktop packages (pipewire stack, waybar, mako,
  wofi, hyprlock, hypridle, hyprpaper, portals, clipboard, screenshot tools,
  polkit agent); home-manager owns the config files (hyprland.lua, kitty.conf,
  waybar, mako, wofi, hyprlock, ...) as plain files symlinked via home.file.
- Still to do after: session entry for start-hyprland at login; SDDM later.

### Checkpoint 5 - Batch 1+2 DONE: all packages installed (2026-08-04)
- Batch 1 (audio): pipewire wireplumber pipewire-pulse pipewire-audio alsa-utils.
  User services enabled (pipewire.socket, pipewire-pulse.socket, wireplumber).
  Verified: aplay -l shows card 1 "CS4208 Analog" (Cirrus HDA, snd_hda_intel);
  wpctl status shows "Built-in Audio Analog Stereo" default sink vol 0.40.
  RTKit warnings in wpctl output are benign (no rtkit installed - optional).
- Batch 2 (the rest) - user weighed alternatives for each, all recommended
  picks chosen: hyprpaper, hyprlock, hypridle, hyprpolkitagent, waybar, mako,
  wofi, wl-clipboard, cliphist, grim+slurp+swappy, xdg-desktop-portal,
  xdg-desktop-portal-hyprland, brightnessctl, thunar, less.
  - Deliberately NOT installed: pamixer (waybar's volume module uses wpctl
    natively - zero extra package), jack2 (chose pipewire-jack at pacman's
    provider prompt so jack API goes through PipeWire).
  - Added less (git pager / man pages were missing).
- Alternative analysis recorded: wallpaper hyprpaper>swww>swaybg; bar
  waybar>hyprpanel>eww; notif mako>swaync; launcher wofi>fuzzel>rofi-wayland;
  file mgr thunar>pcmanfm>yazi; screenshots grim/slurp/swappy>hyprshot;
  auth agent hyprpolkitagent>polkit-kde-agent.

### WRAP-UP checkpoint (deferred, after welcome-screen configs)
- Declarative pacman list: export the system package list as a nix value in
  flake.nix (e.g. systemPackages output) + system-packages.sh running
  `sudo pacman -S --needed $(nix eval .#systemPackages --raw)`; fold into
  rebuild.sh next to home-manager switch (mirrors darwin-rebuild doing brew).
  Gives the brew-under-nix benefit (single source of truth) without pretending
  nix runs pacman (home-manager is user-level, verified - no pacman module).
  Honest limit: list is declarative, NOT reproducible - versions float with
  pacman -Syu; true pinning needs cache archiving. Boot layer (GRUB+LUKS,
  mkinitcpio, SPI keyboard fix) stays in docs/arch-setup-mac.md.
- Session entry for start-hyprland at login; SDDM later.

### Config format change (v0.55+) - MAJOR gotcha
- Hyprland config is now Lua at ~/.config/hypr/hyprland.lua (auto-generated if
  missing; default shipped at /usr/share/hypr/hyprland.lua). The old
  hyprland.conf syntax is deprecated and most online tutorials are stale.
- Source: ArchWiki Hyprland page (flagged "out of date" for this reason) +
  hypr.land news update55.

### Launch changes
- Launch via `start-hyprland` (new wrapper, crash recovery + safe mode), not
  `Hyprland` directly. uwsm start is no longer recommended by upstream.
- Source: ArchWiki Hyprland#Starting.

### Polkit requirement
- ArchWiki: Hyprland will fail to start without the `polkit` package installed
  OR seatd.service running. This install has neither yet -> will need polkit.

### Display manager decision
- Decision: TTY login + manual `start-hyprland` FIRST to isolate variables;
  layer SDDM on later. DM launching is "unofficially supported"; hyprland
  package ships desktop entries.

### Terminal emulator decision -> kitty
- Compared kitty vs ghostty vs wezterm for an iTerm2-on-macOS user moving to
  Arch/Hyprland, planning to run herdr (agent multiplexer).
- herdr clarification: herdr is an AGENT multiplexer (Claude Code/Codex/OpenCode
  panes + blocked/working/done sidebar), NOT a tmux replacement; runs as a TUI
  inside any terminal -> does not discriminate between kitty/ghostty/wezterm.
  Installs via curl script/brew/mise/nix. Source: herdr.dev + reviews.
- WezTerm dropped as candidate: its built-in mux (its main draw) is moot once
  herdr replaces tmux; also one-maintainer project with post-2024 future
  questions. Source: RepoPilot/wezterm repo activity.
- Ghostty (native macOS, zero-config) vs kitty (Linux-first, most configurable,
  kitty keyboard protocol for Neovim ctrl+shift distinction, lighter).
  User chose kitty first.
