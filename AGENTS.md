# Agent instructions for arch-setup

Arch Linux box (`archeus`): Hyprland workstation. The system layer stays
pacman-managed (see `docs/`); standalone home-manager owns user config
files and user tools via `flake.nix` + `home.nix`.

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
  with `build/system-config.sh` (currently only `config/actkbd/`, the
  keyboard-backlight hotkey daemon). Extend that script rather than hand-editing
  `/etc`.
- AUR helper on archeus is `paru`; keep it that way (scripts reference it).

