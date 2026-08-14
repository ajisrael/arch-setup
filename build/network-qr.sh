#!/usr/bin/env bash
# Print a Wi-Fi share QR (WIFI: protocol) for the active connection, so a
# phone can join by scanning. Renders as ANSI blocks for the terminal.
#
#   network-qr.sh            ANSI QR to stdout
#   network-qr.sh --png      write /tmp/wifi-qr.png and notify
#
# Enterprise (802.1x/EAP) networks cannot be shared this way and are refused.
set -euo pipefail

interface=""
png=false
for arg in "$@"; do
    case "$arg" in
        --png) png=true ;;
        *) interface=$arg ;;
    esac
done

if [ -z "$interface" ]; then
    route_device=$(ip route get 1.1.1.1 2>/dev/null | awk '{ for (i = 1; i <= NF; i++) if ($i == "dev") { print $(i + 1); exit } }')
    if [ -n "$route_device" ] && [ -d "/sys/class/net/$route_device/wireless" ]; then
        interface=$route_device
    else
        interface=$(LC_ALL=C nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null |
            awk -F: '$2 == "wifi" && $3 ~ /^connected/ { print $1; exit }')
    fi
fi
[ -n "$interface" ] || { notify-send "Wi-Fi QR" "No active Wi-Fi connection" -h string:x-canonical-private-synchronous:network-qr; exit 1; }

uuid=$(nmcli --get-values GENERAL.CON-UUID device show "$interface" | head -n 1)
[ -n "$uuid" ] && [ "$uuid" != "--" ] || { notify-send "Wi-Fi QR" "No active Wi-Fi connection" -h string:x-canonical-private-synchronous:network-qr; exit 1; }

mapfile -t fields < <(nmcli --show-secrets --escape no --get-values \
    802-11-wireless.ssid,802-11-wireless-security.key-mgmt,802-11-wireless-security.psk,802-11-wireless.hidden,802-11-wireless-security.wep-key0 \
    connection show uuid "$uuid")

ssid=${fields[0]:-}
key_management=${fields[1]:-}
password=${fields[2]:-}
hidden=${fields[3]:-no}
wep_key=${fields[4]:-}

[ -n "$ssid" ] || { notify-send "Wi-Fi QR" "Could not read the Wi-Fi name" -h string:x-canonical-private-synchronous:network-qr; exit 1; }
case "$key_management" in
    *eap*|*ieee8021x*)
        notify-send "Wi-Fi QR" "Enterprise Wi-Fi cannot be shared with a QR code" -h string:x-canonical-private-synchronous:network-qr
        exit 1 ;;
esac

escape() {
    local v=$1
    v=${v//\\/\\\\}
    v=${v//;/\\;}
    v=${v//,/\\,}
    v=${v//:/\\:}
    printf '%s' "$v"
}

if [ -n "$key_management" ] && [ "$key_management" != "none" ]; then
    [ -n "$password" ] || { notify-send "Wi-Fi QR" "Could not read the Wi-Fi password" -h string:x-canonical-private-synchronous:network-qr; exit 1; }
    security=WPA
elif [ -n "$wep_key" ]; then
    password=$wep_key
    security=WEP
else
    security=nopass
fi

payload="WIFI:T:$security;S:$(escape "$ssid");P:$(escape "$password");"
[ "$hidden" = "yes" ] && payload+="H:true;"
payload+=";"

printf '# %s (%s)\n' "$ssid" "$security"
if [ "$png" = "true" ]; then
    qrencode -o /tmp/wifi-qr.png "$payload"
    notify-send "Wi-Fi QR" "$ssid ($security)" --image=/tmp/wifi-qr.png -h string:x-canonical-private-synchronous:network-qr
else
    qrencode -t ANSIUTF8 "$payload"
fi
