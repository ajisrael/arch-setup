# Agent instructions for arch-setup

Arch Linux box (`archeus`): Hyprland workstation. The system layer stays
pacman-managed (see `docs/`); standalone home-manager owns user config
files and user tools via `flake.nix` + `home.nix`.

zsh is the primary interactive shell (chsh to `/usr/bin/zsh`; `zsh` is in
`system-packages.nix`). home-manager's `programs.zsh` generates `~/.zshrc`,
`~/.zshenv`, `~/.zprofile` (classic layout - `xdg.enable` is off, so no
ZDOTDIR bridge) with oh-my-zsh + Powerlevel10k. The theme comes from
`pkgs.zsh-powerlevel10k` (omz `custom` points at its share dir so
`ZSH_THEME="powerlevel10k/powerlevel10k"` resolves); autosuggestions +
syntax-highlighting come from their own HM modules, not omz plugins. The
repo-tracked `config/zsh/personal.zsh` and `config/zsh/p10k.zsh` are linked
to `~/.zshrc.personal` and `~/.p10k.zsh` (`force = true`) and sourced via
`initContent` mkOrder 500 (p10k instant prompt, early) and 1500
(`source "$HOME/.zshrc.personal"`, last - it must run after the theme so the
guarded `p10k reload` in p10k.zsh works). `initExtra`/`initExtraFirst` are
deprecated on the pinned HM master - use `initContent` + `mkOrder`.

The bash prompt (Tokyo Night, mirrors the macOS Powerlevel10k look) lives in
`config/bash/` (`bashrc` + `prompt.bashrc`), symlinked to `~/.bashrc` and
`~/.bash_profile` by home-manager - a fallback for scripts/tty, kept in the
256-color + plain glyph mode rather than forcing icons everywhere. tmux
window names are owned by the zsh preexec/precmd hooks in `personal.zsh`, so
tmux.conf keeps `automatic-rename off`.

## The user always runs ./rebuild.sh themselves

Never run `./rebuild.sh` or `home-manager switch --flake .#archeus` on the
user's behalf - applying a config change is the user's call, not an agent's.
Validate changes instead with:

```sh
nix flake check --no-build
nix build .#homeConfigurations.archeus.activationPackage --dry-run
```

then tell the user the change is ready to apply.

## Nix is a clean slate

This flake is intentionally separate from the macOS nix-darwin setup.
Evaluate merging only after the Arch setup is complete and real overlap is
visible. Inputs pin `nixpkgs-unstable` + home-manager `master` (herdr and
other fresh packages are only on master/unstable).

## Nix on Arch is NOT the stale ArchWiki flow

The Arch `nix` package is socket-activated and uses systemd-sysusers. There
is no `nix-users` group, and any local user can use the daemon. The full
working setup is encoded in `bootstrap.sh` - read its comments before
changing anything around the daemon, and keep the scripts as the source of
truth for the install sequence.

## home-manager SSH gotchas

- `programs.ssh.matchBlocks` is deprecated on current master - use
  `programs.ssh.settings` (attribute names become `Host` blocks, directives
  use OpenSSH names like `IdentityFile`, booleans render as yes/no).
- Setting `programs.ssh.enableDefaultConfig = false` silences the
  "default values will be removed" warning; replicate the defaults at
  `settings."*"` (the module help text has the exact snippet).
- `programs.ssh` owns `~/.ssh/config` and will refuse to overwrite a
  pre-existing hand-written file - set `home.file.".ssh/config".force = true`
  inside the existing `home.file` attrset to clobber it.

## System (root) packages and config are tracked, not nix-managed

home-manager is user-scope only - it cannot install root packages or write
`/etc`. Root-level things are tracked in the repo instead:

- **Packages**: `system-packages.nix` (official repos via pacman + AUR via
  paru). Install with `build/system-packages.sh`, or `./rebuild.sh --packages`.
  Reconcile against the box with `pacman -Qqen` / `pacman -Qqem`. Tracking is
  declarative, NOT version-pinned - versions float with `pacman -Syu`.
- **Root config files**: versioned under `config/<tool>/`, deployed to `/etc`
  with `build/system-config.sh`. Currently `config/actkbd/` (keyboard-backlight
  hotkey daemon) and `config/modprobe.d/` (install reroutes: re-assert the
  `smc::kbd_backlight` floor after applesmc loads for the LUKS prompt, and set
  `intel_backlight` to 50% after i915 loads in the booted system).
  Extend that script rather than hand-editing `/etc`. `modprobe.d` files
  deployed to `/etc/modprobe.d/` get bundled into the initramfs automatically
  by the `modconf` initramfs hook on `mkinitcpio -P` (the script rebuilds the
  image itself when a file changes or the image is stale). Note: udev rules are
  NOT a reliable way to run something inside the initramfs (observed - a rule
  that worked in the booted system never fired there); use a modprobe.d
  reroute.
- AUR helper on archeus is `paru`; keep it that way (scripts reference it).

