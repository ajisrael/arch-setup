#!/usr/bin/env bash
# Bluetooth device picker, launched by waybar's #bluetooth module on-click.
#
# 1. Powers the controller on if it's off.
# 2. Scans for ~8s to discover nearby devices.
# 3. Shows every device in a wofi menu, tagged by state:
#      [CON] AirPods (xx:xx:xx:xx:xx:xx)   -- pick to disconnect
#      [PAI] Keyboard (xx:xx:xx:xx:xx:xx)  -- pick to connect
#      [NEW] Mouse (xx:xx:xx:xx:xx:xx)     -- pick to pair + trust + connect
set -euo pipefail

WOFLAGS=(--dmenu --prompt "Bluetooth" --width 480 --height 380 --location center)

# 1. Make sure the controller is powered on.
if ! bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
    bluetoothctl power on >/dev/null 2>&1 || true
fi

# 2. Short foreground scan to populate the discovered-device list.
timeout 8 bluetoothctl scan on >/dev/null 2>&1 || true
bluetoothctl scan off >/dev/null 2>&1 || true

# 3. Build the menu from known (paired + connected + discovered) devices.
mapfile -t CONNECTED < <(bluetoothctl devices Connected | awk '{print $2}')
mapfile -t PAIRED < <(bluetoothctl devices Paired | awk '{print $2}')

menu=""
while read -r _ mac rest; do
    [[ -z "$mac" ]] && continue
    name="${rest:-$mac}"
    if [[ " ${CONNECTED[*]-} " == *" $mac "* ]]; then
        menu+="[CON] $name ($mac)\n"
    elif [[ " ${PAIRED[*]-} " == *" $mac "* ]]; then
        menu+="[PAI] $name ($mac)\n"
    else
        menu+="[NEW] $name ($mac)\n"
    fi
done < <(bluetoothctl devices)

if [[ -z "$menu" ]]; then
    printf 'No devices found - scan may still be running\n' | wofi "${WOFLAGS[@]}"
    exit 0
fi

choice=$(printf '%b' "$menu" | wofi "${WOFLAGS[@]}")
[[ -z "$choice" ]] && exit 0

mac=$(grep -oE '([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}' <<<"$choice" || true)
[[ -z "$mac" ]] && exit 0

# Picking a connected device disconnects it; anything else connects, pairing
# and trusting first if it's a brand-new device.
if [[ "$choice" == "[CON]"* ]]; then
    bluetoothctl disconnect "$mac" >/dev/null 2>&1
    exit 0
fi

if ! bluetoothctl connect "$mac" >/dev/null 2>&1; then
    bluetoothctl pair "$mac"  >/dev/null 2>&1 || true
    bluetoothctl trust "$mac" >/dev/null 2>&1 || true
    bluetoothctl connect "$mac" >/dev/null 2>&1
fi
