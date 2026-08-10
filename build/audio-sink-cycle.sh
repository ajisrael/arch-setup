#!/usr/bin/env bash
# Cycle the default audio sink through the available sinks (wpctl) and tell
# the user which one is now active via a desktop notification (mako).
#
#   audio-sink-cycle.sh          cycle to the next sink
#   audio-sink-cycle.sh <id>     switch to a specific sink node id
#
# Bound to Super+A in config/hypr/hyprland.lua.
set -euo pipefail

if [ $# -ge 1 ]; then
    wpctl set-default "$1"
    exit 0
fi

# Sink rows live between the "Sinks:" and next "Sources:" header of wpctl status
# and look like " │  *   58. Built-in Audio Analog Stereo  [vol: 0.00]" (the *
# marks the current default).
mapfile -t rows < <(wpctl status | sed -n '/├─ Sinks:/,/├─/p' | tail -n +2 | grep -E '[0-9]+\.[[:space:]]')

ids=()
names=()
current=0
for row in "${rows[@]}"; do
    id="$(printf '%s' "$row" | sed -E 's/^[^0-9]*([0-9]+)\..*/\1/')"
    name="$(printf '%s' "$row" | sed -E 's/^[^0-9]*[0-9]+\.\s*//; s/[[:space:]]*\[vol:.*$//')"
    ids+=("$id")
    names+=("$name")
    [[ "$row" == *"*"* ]] && current=$(( ${#ids[@]} - 1 ))
done

if [ "${#ids[@]}" -le 1 ]; then
    notify-send "Audio" "Only one sink: ${names[0]:-none}" -h string:x-canonical-private-synchronous:audio-sink
    exit 0
fi

next=$(( (current + 1) % ${#ids[@]} ))
wpctl set-default "${ids[$next]}"
notify-send "Audio output" "${names[$next]}" -h string:x-canonical-private-synchronous:audio-sink
