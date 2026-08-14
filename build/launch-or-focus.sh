#!/usr/bin/env bash
# Launch-or-focus: focus the existing window whose class/title matches the
# pattern, otherwise launch the command. A Mac-like ergonomic for Super+<key>.
#
#   launch-or-focus.sh <window-pattern> [launch-command...]
#
# With no launch-command, the pattern itself is launched (e.g. pattern "kitty"
# focuses an open kitty or starts a new one). The window pattern is a case-
# insensitive word-boundary regex matched against class OR title.
#
# Bound in config/hypr/hyprland.lua; used by build/webapp.sh too.
set -euo pipefail

pattern="${1:?usage: launch-or-focus.sh <window-pattern> [launch-command...]}"
shift

addr=$(hyprctl clients -j | jq -r --arg p "$pattern" '
  [ .[] |
    select((.class|test("\\b" + $p + "\\b"; "i")) or (.title|test("\\b" + $p + "\\b"; "i"))) |
    .address ] | first // empty')

if [ -n "$addr" ]; then
    hyprctl dispatch 'hl.dsp.focus({ window = "address:'"$addr"'" })' >/dev/null
else
    if [ $# -eq 0 ]; then
        set -- "$pattern"
    fi
    setsid "$@" >/dev/null 2>&1 &
    disown
fi
