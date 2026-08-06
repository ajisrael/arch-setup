#!/usr/bin/env bash
# Install the declaratively-tracked system package lists (system-packages.nix):
#   - systemPackages: official Arch repositories (via pacman)
#   - aurPackages:    Arch User Repository       (via paru)
#
# home-manager is user-scope only, so the root-level package set lives in
# system-packages.nix - the single source of truth for a fresh install.
# Safe to re-run (--needed skips already-installed packages).
#
# Prerequisites: nix (bootstrap.sh) and paru for the AUR list (see
# docs/arch-setup-mac.md). Reconcile the list against the box with
# `pacman -Qqen` / `pacman -Qqem`.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

if ! command -v nix >/dev/null 2>&1; then
  echo "nix not found - run bootstrap.sh first" >&2
  exit 1
fi

nix_eval() {
  nix eval --raw --impure --expr \
    "builtins.concatStringsSep \" \" (import \"$DIR/system-packages.nix\").$1"
}

echo "==> Official repos (pacman)"
sys_pkgs=$(nix_eval systemPackages)
sudo pacman -S --needed $sys_pkgs

echo "==> AUR (paru)"
aur_pkgs=$(nix_eval aurPackages)
if [ -n "$aur_pkgs" ]; then
  if ! command -v paru >/dev/null 2>&1; then
    echo "paru not found - install it first (see docs/arch-setup-mac.md)" >&2
    exit 1
  fi
  paru -S --needed $aur_pkgs
else
  echo "    no AUR packages tracked"
fi

echo "==> Done. System packages are up to date with system-packages.nix"
