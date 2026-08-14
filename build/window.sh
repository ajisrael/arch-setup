#!/usr/bin/env bash
# Window toggles for Hyprland (Lua-mode dispatch DSL). Ported from Omarchy's
# omarchy-hyprland-window-* set, adapted to the native hl.dsp.* API.
#
#   window.sh gaps            toggle gaps_in/gaps_out between 0 and last value
#   window.sh transparency    toggle opaque on the focused window
#   window.sh fullscreen      toggle tiled (client) fullscreen
#   window.sh square          toggle single-window 1:1 aspect ratio
#   window.sh pop             pop the focused tile out (float, pin, +pop tag)
#   window.sh width-save      remember the focused window's width (per class+ws)
#   window.sh width-restore   resize the focused window back to the saved width
#   window.sh close-all       close every window and return to workspace 1
#
# Binds live in config/hypr/hyprland.lua.
set -euo pipefail

STATE_DIR="$HOME/.local/state/hypr-window"

dsp() { hyprctl dispatch "$1" >/dev/null; }

active() { hyprctl activewindow -j; }

active_addr() { jq -r '.address // empty' < <(active); }

usage() {
    sed -n '2,15p' "${BASH_SOURCE[0]}" | sed 's/^# //; s/^#$//; /^$/d'
    exit "${1:-0}"
}

cmd="${1:-}"; [ -n "$cmd" ] || usage 1
shift

case "$cmd" in
    gaps)
        # Save the current box values on the way out, restore them on the way
        # back, so the toggle is exact even if the config default changes.
        gin_css=$(hyprctl getoption general:gaps_in -j | jq -r '.css')
        gout_css=$(hyprctl getoption general:gaps_out -j | jq -r '.css')
        if [ -f "$STATE_DIR/gaps" ]; then
            read -r saved_gin saved_gout <"$STATE_DIR/gaps"
            dsp "hl.config({ general = { gaps_in = $saved_gin, gaps_out = $saved_gout } })"
            rm -f "$STATE_DIR/gaps"
            notify-send "Window gaps" "Restored ($saved_gin / $saved_gout)" -h string:x-canonical-private-synchronous:window-gaps
        else
            mkdir -p "$STATE_DIR"
            printf '%s\n%s' "$gin_css" "$gout_css" >"$STATE_DIR/gaps"
            dsp "hl.config({ general = { gaps_in = 0, gaps_out = 0 } })"
            notify-send "Window gaps" "Removed" -h string:x-canonical-private-synchronous:window-gaps
        fi
        ;;
    transparency)
        addr=$(active_addr); [ -n "$addr" ] || exit 1
        dsp "hl.dsp.window.set_prop({ window = \"address:$addr\", prop = \"opaque\", value = \"toggle\" })"
        ;;
    fullscreen)
        full=$(jq -r '.fullscreenClient // 0' < <(active))
        if [ "$full" = "2" ]; then
            dsp 'hl.dsp.window.fullscreen_state({ internal = 0, client = 0 })'
        else
            dsp 'hl.dsp.window.fullscreen_state({ internal = 0, client = 2 })'
        fi
        ;;
    square)
        current=$(hyprctl getoption layout:single_window_aspect_ratio | awk '{print $2}')
        if [ "${current%%,*}" != "0" ]; then
            dsp 'hl.config({ layout = { single_window_aspect_ratio = { 0, 0 } } })'
            notify-send "Window aspect" "1:1 square off" -h string:x-canonical-private-synchronous:window-square
        else
            dsp 'hl.config({ layout = { single_window_aspect_ratio = { 1, 1 } } })'
            notify-send "Window aspect" "1:1 square on" -h string:x-canonical-private-synchronous:window-square
        fi
        ;;
    pop)
        width=${1:-1300}; height=${2:-900}; x=${3:-}; y=${4:-}
        win=$(active)
        addr=$(jq -r '.address' <<<"$win"); [ -n "$addr" ] || exit 1
        w="address:$addr"
        if [ "$(jq -r '.pinned' <<<"$win")" = "true" ]; then
            dsp "hl.dsp.window.pin({ window = \"$w\" })"
            dsp "hl.dsp.window.float({ window = \"$w\", action = \"toggle\" })"
            dsp "hl.dsp.window.tag({ window = \"$w\", tag = \"-pop\" })"
        else
            dsp "hl.dsp.window.float({ window = \"$w\", action = \"toggle\" })"
            dsp "hl.dsp.window.resize({ window = \"$w\", x = $width, y = $height })"
            if [ -n "$x" ] && [ -n "$y" ]; then
                dsp "hl.dsp.window.move({ window = \"$w\", x = $x, y = $y })"
            else
                dsp "hl.dsp.window.center({ window = \"$w\" })"
            fi
            dsp "hl.dsp.window.pin({ window = \"$w\" })"
            dsp "hl.dsp.window.alter_zorder({ window = \"$w\", mode = \"top\" })"
            dsp "hl.dsp.window.tag({ window = \"$w\", tag = \"+pop\" })"
        fi
        ;;
    width-save)
        win=$(active)
        key=$(jq -r '[.class, .initialClass, .title] | map(select(. != null and . != "")) | first // empty' <<<"$win")
        ws=$(jq -r '.workspace.id // .workspace.name // empty' <<<"$win")
        [ -n "$key" ] && [ -n "$ws" ] || exit 1
        width=$(jq -er '.size[0]' <<<"$win")
        fname="${ws}-${key}"; fname="${fname//\//_}"; fname="${fname//$'\n'/_}"
        mkdir -p "$STATE_DIR"
        printf '%s\n' "$width" >"$STATE_DIR/$fname.width"
        notify-send "Window width" "Saved $width for $key on workspace $ws" -h string:x-canonical-private-synchronous:window-width
        ;;
    width-restore)
        win=$(active)
        key=$(jq -r '[.class, .initialClass, .title] | map(select(. != null and . != "")) | first // empty' <<<"$win")
        ws=$(jq -r '.workspace.id // .workspace.name // empty' <<<"$win")
        addr=$(jq -r '.address' <<<"$win")
        [ -n "$key" ] && [ -n "$ws" ] && [ -n "$addr" ] || exit 1
        fname="${ws}-${key}"; fname="${fname//\//_}"; fname="${fname//$'\n'/_}"
        f="$STATE_DIR/$fname.width"
        [ -f "$f" ] || { notify-send "Window width" "No saved width for $key on workspace $ws" -h string:x-canonical-private-synchronous:window-width; exit 1; }
        target=$(<"$f")
        [[ "$target" =~ ^[0-9]+$ ]] || exit 1
        w="address:$addr"
        current=$(jq -r '.size[0]' <<<"$win")
        # Hyprland caps resizeactive widths; clamp by nudging toward the target.
        while [ "$current" -lt "$target" ]; do
            delta=$((target - current))
            [ "$delta" -gt 500 ] && delta=500
            dsp "hl.dsp.window.resize({ window = \"$w\", x = $delta, y = 0, relative = true })"
            new=$(jq -r '.size[0]' < <(hyprctl clients -j | jq --arg a "$addr" '.[] | select(.address == $a)'))
            [ "$new" = "$current" ] && break
            current=$new
        done
        notify-send "Window width" "Restored $target for $key on workspace $ws" -h string:x-canonical-private-synchronous:window-width
        ;;
    close-all)
        mapfile -t addrs < <(hyprctl clients -j | jq -r '.[].address')
        for a in "${addrs[@]}"; do
            dsp "hl.dsp.window.close({ window = \"address:$a\" })"
        done
        dsp 'hl.dsp.focus({ workspace = 1 })'
        ;;
    *) usage 1 ;;
esac
