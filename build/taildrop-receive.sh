#!/usr/bin/env bash
# Receive Taildrop files into ~/Downloads (or the given directory) and announce
# each delivery via mako. Runs as a user service (home.nix
# systemd.user.services."taildrop-receive").
#
# Taildrop lands in a staging dir next to the target directory (same
# filesystem), then each file is claimed with a hardlink+rename so it appears
# atomically - no partial delivery ever sits in Downloads. An interrupted run
# delivers anything left staged before waiting again.
#
#   taildrop-receive.sh [--once] [directory]
set -euo pipefail

once=false
if [ "${1:-}" = "--once" ]; then
    once=true
    shift
fi

dir="${1:-${XDG_DOWNLOAD_DIR:-$HOME/Downloads}}"
staging="$dir/.taildrop"
mkdir -p "$staging"

claim_path() {
    local staged="$1" name="${staged##*/}" base ext candidate index=0
    base="${name%.*}"; ext="${name#"$base"}"
    [ -n "$base" ] || { base="$name"; ext=""; }

    while (( index < 1000 )); do
        if (( index == 0 )); then
            candidate="$dir/$name"
        else
            candidate="$dir/$base-$index$ext"
        fi

        # link(2) refuses an existing name, so nothing can race the chosen one.
        if ln -- "$staged" "$candidate" 2>/dev/null; then
            rm -f -- "$staged"
            printf '%s\n' "$candidate"
            return 0
        fi
        [[ -e $candidate ]] || return 1
        ((index++))
    done
    return 1
}

announce() {
    local path="$1" name="${1##*/}" args=()
    case "${name,,}" in
        *.png|*.jpg|*.jpeg|*.gif|*.webp|*.avif|*.bmp|*.tif|*.tiff)
            args=(--image "$path")
            ;;
    esac
    # Clicking the toast opens the file (mako default action).
    if [ -n "$(notify-send "Received $name" "Saved to ${dir/#$HOME/~}" -a taildrop-receive "${args[@]}" --action=default=Open 2>/dev/null)" ]; then
        xdg-open "$path"
    fi
}

deliver() {
    local staged target
    while IFS= read -r staged; do
        target=$(claim_path "$staged") || continue
        announce "$target" &
    done < <(find "$staging" -mindepth 1 -maxdepth 1)
}

# Anything left staged by an interrupted run still deserves delivering.
deliver

while true; do
    if ! tailscale file get --wait --conflict=rename "$staging"; then
        $once && exit 1
        sleep 10
        continue
    fi

    deliver
    $once && exit 0
done
