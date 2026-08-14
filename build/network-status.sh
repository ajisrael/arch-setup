#!/usr/bin/env bash
# Active network status: type, device, SSID, signal, freq, and IPv4 address
# for the default-route interface. Tab-separated, so it can feed a waybar
# custom module or a quick terminal check.
set -euo pipefail

PROBE=1.1.1.1

dev=$(ip route get "$PROBE" 2>/dev/null | awk '{ for (i = 1; i <= NF; i++) if ($i == "dev") { print $(i + 1); exit } }')

if [ -z "$dev" ]; then
    printf 'disconnected\n'
    exit 0
fi

ip4() {
    ip -4 addr show "$dev" 2>/dev/null | awk '/inet / { print "ip\t" $2; exit }'
}

if [ ! -d "/sys/class/net/$dev/wireless" ]; then
    printf 'ethernet\t%s\n' "$dev"
    ip4
    exit 0
fi

ssid=$(nmcli -t -f GENERAL.CONNECTION dev show "$dev" 2>/dev/null | awk -F: '$1 == "GENERAL.CONNECTION" { print $2; exit }')
signal=$(nmcli -t -f IN-USE,SIGNAL dev wifi list ifname "$dev" --rescan no 2>/dev/null | awk -F: '$1 == "*" { print $2; exit }')
freq=$(iw dev "$dev" link 2>/dev/null | awk '/freq:/ { print $2; exit }')

printf 'wifi\t%s\t%s%%\t%s MHz\n' "${ssid:-$dev}" "${signal:-?}" "${freq:-?}"
ip4
