#!/usr/bin/env bash
# Screenshot suite (grim + slurp + swappy): region by default, with
# fullscreen, focused-window and quick-copy variants. Files land in
# ~/Pictures/screenshots.
#
#   screenshot.sh         region -> swappy editor
#   screenshot.sh full    fullscreen -> swappy
#   screenshot.sh window  focused window -> swappy
#   screenshot.sh copy    region -> clipboard (no editor)
#
# Bound to Super+Shift+S in config/hypr/hyprland.lua.
set -euo pipefail

SAVE_DIR="$HOME/Pictures/screenshots"
mkdir -p "$SAVE_DIR"

file="$SAVE_DIR/$(date +%Y%m%d-%H%M%S).png"

# Focused-window geometry from `hyprctl activewindow` (no jq dependency):
# "x,y WxH" for grim -g. Empty when nothing is focused.
geometry() {
    hyprctl activewindow 2>/dev/null | awk -F': ' '
        /^\s*at:/{a=$2; gsub(/ /,"",a)}
        /^\s*size:/{s=$2; gsub(/ /,"",s); sub(/,/,"x",s)}
        END{if (a && s) print a" "s}'
}

case "${1:-region}" in
    full)
        grim "$file"
        ;;
    window)
        geom="$(geometry)"
        if [ -n "$geom" ]; then
            grim -g "$geom" "$file"
        else
            notify-send "Screenshot" "No focused window; falling back to region" -h string:x-canonical-private-synchronous:capture
            grim -g "$(slurp)" "$file"
        fi
        ;;
    copy)
        grim -g "$(slurp)" - | wl-copy
        notify-send "Screenshot" "Region copied to clipboard" -h string:x-canonical-private-synchronous:capture
        exit 0
        ;;
    region|*)
        grim -g "$(slurp)" "$file"
        ;;
esac

notify-send "Screenshot" "Saved: $file" -h string:x-canonical-private-synchronous:capture
swappy -f "$file"
