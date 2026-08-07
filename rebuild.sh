#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

if [[ "${1:-}" == "--packages" ]]; then
  bash "$DIR/build/system-packages.sh"
fi

home-manager switch --flake "$DIR#archeus"

# waybar doesn't hot-reload its config, so bounce it to pick up the freshly
# linked config.jsonc/style.css. Relaunch it against the live session's
# Wayland socket: the shell's HYPRLAND_INSTANCE_SIGNATURE / WAYLAND_DISPLAY
# can be stale (e.g. outlived a relogin), and hyprctl dispatch is lua-eval'ed
# and fragile - launching waybar straight at the live display is more robust.
# Skipped when no session is reachable (hyprctl instances is empty from a TTY).
WL_SOCK="$(hyprctl instances 2>/dev/null | awk '/wl socket:/{print $3; exit}')"
if [[ -n "$WL_SOCK" ]]; then
  pkill -x waybar 2>/dev/null || true
  WAYLAND_DISPLAY="$WL_SOCK" nohup waybar >/dev/null 2>&1 &
fi

echo "Rebuild successful!"
