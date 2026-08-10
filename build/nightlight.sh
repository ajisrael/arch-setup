#!/usr/bin/env bash
# Nightlight toggle (hyprsunset): warm 4000K on, normal off.
#
#   nightlight.sh toggle  (default)
#   nightlight.sh on
#   nightlight.sh off
#   nightlight.sh status
#
# Bound to Super+Shift+N in config/hypr/hyprland.lua. hyprsunset stays
# running while the filter is active (killing it resets the gamma), so the
# toggle tracks its pid in $XDG_RUNTIME_DIR.
set -euo pipefail

TEMP=4000
STATE="${XDG_RUNTIME_DIR:-/tmp}/nightlight.pid"

is_on() {
    [ -f "$STATE" ] && kill -0 "$(<"$STATE")" 2>/dev/null
}

on() {
    if is_on; then
        notify-send "Nightlight" "Already on ($TEMP K)" -h string:x-canonical-private-synchronous:nightlight
        return
    fi
    if ! command -v hyprsunset >/dev/null 2>&1; then
        notify-send "Nightlight" "hyprsunset not installed (system-packages.nix)" -h string:x-canonical-private-synchronous:nightlight
        exit 1
    fi
    rm -f "$STATE" # stale pid from a dead process
    hyprsunset -t "$TEMP" &
    echo $! > "$STATE"
    notify-send "Nightlight" "On ($TEMP K)" -h string:x-canonical-private-synchronous:nightlight
}

off() {
    if [ -f "$STATE" ]; then
        kill -TERM "$(<"$STATE")" 2>/dev/null || true
        rm -f "$STATE"
    fi
    pkill -x hyprsunset 2>/dev/null || true # untracked instance
    notify-send "Nightlight" "Off" -h string:x-canonical-private-synchronous:nightlight
}

case "${1:-toggle}" in
    toggle) if is_on; then off; else on; fi ;;
    on) on ;;
    off) off ;;
    status)
        if is_on; then echo "on (pid $(<"$STATE"), $TEMP K)"; else echo off; fi ;;
    *) echo "usage: nightlight.sh [toggle|on|off|status]" >&2; exit 1 ;;
esac
