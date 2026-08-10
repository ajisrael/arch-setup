#!/usr/bin/env bash
# Restart the PipeWire audio stack (wireplumber -> pipewire -> pipewire-pulse)
# and recover wedged components. If a unit will not restart cleanly it is
# force-killed; the session runs under systemd, so it is respawned.
# Modelled on Omarchy's omarchy-restart-audio. Bound to Super+Shift+A in
# config/hypr/hyprland.lua.
set -euo pipefail

for unit in wireplumber.service pipewire.service pipewire-pulse.service; do
    state="$(systemctl --user show -P ActiveState --no-pager "$unit" 2>/dev/null || true)"
    if [ "$state" = "inactive" ] || [ "$state" = "failed" ]; then
        systemctl --user reset-failed "$unit" 2>/dev/null || true
        systemctl --user start "$unit"
        continue
    fi
    if ! systemctl --user restart "$unit"; then
        echo "==> $unit stuck; force-killing"
        pkill -9 -x "${unit%.service}" || true
        systemctl --user reset-failed "$unit" 2>/dev/null || true
        systemctl --user start "$unit" || true
    fi
done

# A USB audio device that re-enumerated with a new node id can leave the
# session with no default sink; wireplumber usually re-picks one, this is the
# fallback.
if command -v wpctl >/dev/null 2>&1; then
    current="$(wpctl status | grep -cE '^[[:space:]]*\*[[:space:]]+[0-9]+\.')" || true
    if [ "$current" -eq 0 ]; then
        id="$(wpctl status | sed -n '/├─ Sinks:/,/├─/p' | tail -n +2 | grep -E '[0-9]+\.[[:space:]]' | head -1 | sed -E 's/^[^0-9]*([0-9]+)\..*/\1/')"
        [ -n "$id" ] && wpctl set-default "$id"
    fi
fi

notify-send "Audio" "Audio stack restarted" -h string:x-canonical-private-synchronous:audio-sink
