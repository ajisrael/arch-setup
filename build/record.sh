#!/usr/bin/env bash
# Screen recording toggle (wf-recorder). First call starts, second call stops
# and finalizes. Region by default, fullscreen with `full`.
#
#   record.sh         toggle region recording
#   record.sh full    toggle fullscreen recording
#
# Bound to Super+Shift+R in config/hypr/hyprland.lua.
set -euo pipefail

OUT="$HOME/Videos/recordings"
STATE="${XDG_RUNTIME_DIR:-/tmp}/record"
mkdir -p "$OUT" "$STATE"

if [ -f "$STATE/pid" ]; then
    pid="$(<"$STATE/pid")"
    if kill -0 "$pid" 2>/dev/null; then
        kill -INT "$pid"
        while kill -0 "$pid" 2>/dev/null; do sleep 0.1; done
        rm -f "$STATE/pid"
        last="$(ls -t "$OUT"/*.mp4 2>/dev/null | head -1)"
        notify-send "Recording" "Saved: ${last##*/}" -h string:x-canonical-private-synchronous:record
    else
        rm -f "$STATE/pid"
        notify-send "Recording" "Stale recording state cleared" -h string:x-canonical-private-synchronous:record
    fi
    exit 0
fi

if ! command -v wf-recorder >/dev/null 2>&1; then
    notify-send "Recording" "wf-recorder not installed (system-packages.nix)" -h string:x-canonical-private-synchronous:record
    exit 1
fi

file="$OUT/$(date +%Y%m%d-%H%M%S).mp4"
if [ "${1:-region}" = full ]; then
    wf-recorder -o "$file" &
else
    geom="$(slurp)" || exit 1
    wf-recorder -g "$geom" -o "$file" &
fi
echo $! > "$STATE/pid"
notify-send "Recording" "Recording started - toggle again to stop" -h string:x-canonical-private-synchronous:record
