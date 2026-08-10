#!/usr/bin/env bash
# Per-state power profiles: apply a powerprofilesctl profile based on whether
# the machine is on AC or battery, and persist per-state overrides.
#
# Usage:
#   power-profile.sh                     apply the profile for the current state
#   power-profile.sh set <state> <name>  persist a per-state override (ac|battery)
#   power-profile.sh status              show current state + active profile
#   power-profile.sh --help              this help
#
# The udev rule config/udev/rules.d/90-power-profile.rules fires this on every
# Mains plug/unplug; config/hypr/hyprland.lua autostarts it at login for the
# boot state. Defaults when no override is set: battery -> power-saver, AC ->
# balanced.
set -euo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/power-profile"
AC_PROFILE="${AC_PROFILE:-balanced}"
BATTERY_PROFILE="${BATTERY_PROFILE:-power-saver}"

# Root invocations (manual sudo) re-run as the desktop user so per-state
# overrides stay in the user's state dir. udev already goes through runuser.
if [ "$(id -u)" -eq 0 ]; then
    exec runuser -u ajisrael -- "$0" "$@"
fi

current_state() {
    for d in /sys/class/power_supply/*/; do
        [ "$(<"$d/type")" = "Mains" ] || continue
        if [ "$(<"$d/online")" = "1" ]; then
            echo ac
            return
        fi
    done
    echo battery
}

apply() {
    local state profile
    state="$(current_state)"
    if [ -f "$STATE_DIR/$state" ]; then
        profile="$(<"$STATE_DIR/$state")"
    elif [ "$state" = battery ]; then
        profile="$BATTERY_PROFILE"
    else
        profile="$AC_PROFILE"
    fi

    if command -v powerprofilesctl >/dev/null 2>&1; then
        powerprofilesctl set "$profile"
        echo "power profile: $state -> $profile"
    else
        echo "warning: powerprofilesctl not found - install power-profiles-daemon (system-packages.nix)" >&2
    fi
}

set_profile() {
    local state="$1" name="$2"
    case "$state" in
        ac|battery) ;;
        *) echo "error: state must be ac or battery" >&2; exit 1 ;;
    esac
    [ -n "$name" ] || { echo "error: profile name required" >&2; exit 1; }
    mkdir -p "$STATE_DIR"
    printf '%s\n' "$name" > "$STATE_DIR/$state"
    echo "power profile: $state -> $name (persisted)"
}

status() {
    local state
    state="$(current_state)"
    echo "AC/battery: $state"
    if command -v powerprofilesctl >/dev/null 2>&1; then
        echo "active profile: $(powerprofilesctl get)"
    else
        echo "power-profiles-daemon not installed yet"
    fi
    for s in ac battery; do
        if [ -f "$STATE_DIR/$s" ]; then
            echo "persisted $s: $(<"$STATE_DIR/$s")"
        else
            echo "persisted $s: (default)"
        fi
    done
}

case "${1:-}" in
    ""|apply) apply ;;
    set) set_profile "${2:-}" "${3:-}" ;;
    status) status ;;
    --help|-h|help) sed -n '2,16p' "${BASH_SOURCE[0]}" | sed 's/^# //' ;;
    *) echo "error: unknown subcommand: $1" >&2
       sed -n '2,16p' "${BASH_SOURCE[0]}" | sed 's/^# //' >&2
       exit 1 ;;
esac
