#!/usr/bin/env bash
# Send files to another machine on the tailnet via Taildrop (tailscale file cp).
# The receiver is named by MagicDNS short name (e.g. "dhh-fd").
#
#   taildrop-send.sh <machine> [file...]
set -euo pipefail

usage() {
    sed -n '2,6p' "${BASH_SOURCE[0]}" | sed 's/^# //; /^$/d'
}

if (($# < 1)); then
    usage >&2
    exit 1
fi

machine="$1"
shift
name="${machine%%.*}"

if (($# == 0)); then
    echo "error: pass one or more files to send (e.g. taildrop-send.sh host ~/notes.pdf)" >&2
    exit 1
fi

if (($# == 1)); then
    what=$(basename "$1")
else
    what="$# files"
fi

if error=$(tailscale file cp --update-interval=0 -- "$@" "$machine:" 2>&1); then
    notify-send "Taildrop" "Sent to $name" "$what" -h string:x-canonical-private-synchronous:taildrop
else
    notify-send -u critical "Taildrop" "Could not send to $name" "${error:-Taildrop transfer failed}" -h string:x-canonical-private-synchronous:taildrop
    exit 1
fi
