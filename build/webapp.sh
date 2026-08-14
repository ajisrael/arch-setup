#!/usr/bin/env bash
# Launch (or focus) a site as an isolated Chrome app window with its own
# profile, so PWA-style apps keep separate cookies/logins from the main
# browser. The WM_CLASS is the app name, so launch-or-focus finds it again.
#
#   webapp.sh <name> <url> [chrome-args...]
set -euo pipefail

name="${1:?usage: webapp.sh <name> <url>}"
shift
url="${1:?usage: webapp.sh <name> <url>}"
shift

prof="${XDG_DATA_HOME:-$HOME/.local/share}/webapps/$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]' | sed 's/[^[:alnum:]._-]/_/g')"

exec /home/ajisrael/arch-setup/build/launch-or-focus.sh "$name" \
    google-chrome --class="$name" --user-data-dir="$prof" --app="$url" "$@"
