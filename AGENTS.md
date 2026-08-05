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
