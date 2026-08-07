#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

if [[ "${1:-}" == "--packages" ]]; then
  bash "$DIR/build/system-packages.sh"
fi

home-manager switch --flake "$DIR#archeus"

# waybar doesn't hot-reload its config, so bounce it to pick up the freshly
# linked config.jsonc/style.css. Only meaningful inside the live Hyprland
# session - hyprctl instances is empty from a bare TTY, so this is skipped.
if command -v hyprctl >/dev/null 2>&1 && [[ -n "$(hyprctl instances 2>/dev/null)" ]]; then
  pkill -x waybar 2>/dev/null || true
  hyprctl dispatch exec waybar
fi

echo "Rebuild successful!"
