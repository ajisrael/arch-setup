#!/usr/bin/env bash
# Keybinding cheatsheet: render the binds declared in config/hypr/hyprland.lua
# as "COMBO \t description", using the config's own comments as the docs.
#
#   keybindings.sh          show in a wofi search menu
#   keybindings.sh --print  plain listing to stdout
#
# Bound to Super+/ in config/hypr/hyprland.lua.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
CONFIG="$DIR/config/hypr/hyprland.lua"

render() {
    gawk -f "$DIR/build/keybindings.awk" "$CONFIG" | sort -u
}

if [ "${1:-}" = "--print" ]; then
    render
    exit 0
fi

lines=$(render)
if [ -z "$lines" ]; then
    notify-send "Keybindings" "No binds found in hyprland.lua" -h string:x-canonical-private-synchronous:keybindings
    exit 1
fi

selection=$(printf '%s\n' "$lines" | wofi --dmenu -p "Keybindings" --width 640 --height 480)
[ -n "$selection" ] || exit 0
