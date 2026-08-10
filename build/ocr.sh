#!/usr/bin/env bash
# OCR a screenshot region into the clipboard (grim + slurp + tesseract).
#
#   ocr.sh         region OCR
#   ocr.sh full    fullscreen OCR
#
# Bound to Super+Shift+O in config/hypr/hyprland.lua.
set -euo pipefail

tmp="$(mktemp --suffix=.png)"
trap 'rm -f "$tmp"' EXIT

if [ "${1:-region}" = full ]; then
    grim "$tmp"
else
    grim -g "$(slurp)" "$tmp"
fi

if ! command -v tesseract >/dev/null 2>&1; then
    notify-send "OCR" "tesseract not installed (system-packages.nix)" -h string:x-canonical-private-synchronous:ocr
    exit 1
fi

text="$(tesseract "$tmp" - 2>/dev/null)"
if [ -n "$text" ]; then
    wl-copy "$text"
    notify-send "OCR" "Copied $(printf '%s' "$text" | wc -w) words to clipboard" -h string:x-canonical-private-synchronous:ocr
else
    notify-send "OCR" "No text recognized" -h string:x-canonical-private-synchronous:ocr
fi
