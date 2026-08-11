#!/usr/bin/env bash
# Install the declaratively-tracked system package lists (system-packages.nix):
#   - systemPackages: official Arch repositories (via pacman)
#   - aurPackages:    Arch User Repository       (via paru)
#
# home-manager is user-scope only, so the root-level package set lives in
# system-packages.nix - the single source of truth for a fresh install.
# Safe to re-run (--needed skips already-installed packages).
#
# A package that no longer resolves (renamed, removed, or a stale entry in
# system-packages.nix) is warned about and skipped instead of aborting the
# whole run - the rest of the list still installs. If the AUR query itself
# fails (offline / RPC down) the package is still attempted so a transient
# network problem doesn't silently skip real packages.
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

# Official repos are resolved against the local sync DBs - the exact same
# ones a `pacman -S` would use - so the check matches reality. base /
# base-devel resolve here like any other meta-package.
repo_pkg_exists() {
  pacman -Ssq "^${1}\$" | grep -qx "$1"
}

warn_skipped() {
  local source="$1"
  shift
  echo "warning: ${source} packages not found and skipped: $*" >&2
  echo "         (stale entry in system-packages.nix, or renamed/removed upstream)" >&2
}

echo "==> Official repos (pacman)"
sys_pkgs=$(nix_eval systemPackages)
PRESENT=()
MISSING=()
for pkg in $sys_pkgs; do
  if repo_pkg_exists "$pkg"; then
    PRESENT+=("$pkg")
  else
    MISSING+=("$pkg")
  fi
done

if [ "${#MISSING[@]}" -gt 0 ]; then
  warn_skipped "official-repo" "${MISSING[*]}"
fi

if [ "${#PRESENT[@]}" -gt 0 ]; then
  sudo pacman -S --needed "${PRESENT[@]}"
else
  echo "    no official packages to install (skipped: ${MISSING[*]:-none})"
fi

echo "==> AUR (paru)"
aur_pkgs=$(nix_eval aurPackages)
if [ -n "$aur_pkgs" ]; then
  if ! command -v paru >/dev/null 2>&1; then
    echo "paru not found - install it first (see docs/arch-setup-mac.md)" >&2
    exit 1
  fi

  aur_present=()
  aur_missing=()
  for pkg in $aur_pkgs; do
    err_file="$(mktemp)"
    # paru -Ssq prints the exact package name on a match. No match = stale
    # AUR entry (skip). An error written to stderr = the query itself failed
    # (offline / AUR RPC down) - keep the package so a transient network
    # problem doesn't silently skip real ones, and let the install surface it.
    if out=$(paru -Ssq "$pkg" 2>"$err_file"); then
      if grep -qx "$pkg" <<<"$out"; then
        aur_present+=("$pkg")
      else
        aur_missing+=("$pkg")
      fi
    elif [ -s "$err_file" ]; then
      aur_present+=("$pkg")
      echo "warning: could not verify $pkg on AUR (query failed) - attempting anyway" >&2
    else
      aur_missing+=("$pkg")
    fi
    rm -f "$err_file"
  done

  if [ "${#aur_missing[@]}" -gt 0 ]; then
    warn_skipped "AUR" "${aur_missing[*]}"
  fi

  if [ "${#aur_present[@]}" -gt 0 ]; then
    paru -S --needed "${aur_present[@]}"
  else
    echo "    no AUR packages to install"
  fi
else
  echo "    no AUR packages tracked"
fi

echo "==> Done. System packages are up to date with system-packages.nix"
