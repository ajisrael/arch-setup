# Parses config/hypr/hyprland.lua (via gawk) into "COMBO<TAB>description"
# records. Descriptions come from inline `-- ...` comments after the closing
# paren of the bind call, else the comment block immediately above. Binds with
# no comment fall back to a label derived from the dsp call. Section divider
# comments (---- title ----) are skipped, as are un-resolvable binds.
BEGIN {
    block_len = 0
    last = ""
}

# Config variable definitions ("local terminal = \"kitty\"" etc).
/^local[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=/ {
    if (match($0, /local[[:space:]]+([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=[[:space:]]*"([^"]+)"/, m)) {
        vars[m[1]] = m[2]
    }
}

# Comment line: accumulate the block above a bind (trimmed), skip dividers.
/^[[:space:]]*--/ {
    line = $0
    sub(/^[[:space:]]*--+[[:space:]]*/, "", line)
    if (line ~ /^----/ || line ~ /^-*[[:space:]]*$/) { next }
    # Comment that points at a bind above it, not below (e.g. "the screenshot
    # bind above") - would mislabel the next bind.
    if (line ~ /above$/) { next }
    block[block_len++] = line
    last = line
    next
}

function join_block(   i, out) {
    out = ""
    for (i = 0; i < block_len; i++) {
        if (out != "") out = out " "
        out = out block[i]
    }
    return out
}

# Fallback label for binds that have no comment to explain them.
function action_label(arg,   a, cmd, script) {
    a = arg
    if (match(a, /hl\.dsp\.exec_cmd\([^)]*\)/, m)) {
        cmd = m[0]
        sub(/^hl\.dsp\.exec_cmd\(/, "", cmd)
        sub(/\)$/, "", cmd)
        gsub(/["'']/, "", cmd)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", cmd)

        # Resolve config variables used as the command.
        if (cmd == "terminal" && "terminal" in vars) cmd = vars["terminal"]
        if (cmd == "fileManager" && "fileManager" in vars) cmd = vars["fileManager"]
        if (cmd == "menu" && "menu" in vars) cmd = vars["menu"]

        if (cmd == "hyprlock") return "Lock screen"
        if (cmd ~ /^wtype -M ctrl c/) return "Copy (synthesized Ctrl+C)"
        if (cmd ~ /^wtype -M ctrl v/) return "Paste (synthesized Ctrl+V)"
        if (cmd ~ /^command -v hyprshutdown/) return "Shut down / exit"
        if (cmd ~ /^google-chrome/) return "Open browser"
        if (cmd == "wofi --show drun") return "Launch apps"
        if (cmd ~ /wpctl set-volume -l 1.*5%\+/) return "Volume up"
        if (cmd ~ /wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-/) return "Volume down"
        if (cmd ~ /wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle/) return "Mute audio"
        if (cmd ~ /wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle/) return "Mute microphone"

        script = cmd
        sub(/^.*\//, "", script)
        if (script == "screenshot.sh") return "Screenshot (region/full/window/copy)"
        if (script == "record.sh") return "Toggle screen recording"
        if (script == "ocr.sh") return "OCR selection to clipboard"
        if (script == "nightlight.sh") return "Toggle nightlight"
        if (script == "audio-sink-cycle.sh") return "Cycle audio sink"
        if (script == "restart-audio.sh") return "Restart audio stack"
        if (script == "power-profile.sh") return "Re-apply power profile"
        if (script ~ /^launch-or-focus\.sh/) return "Focus or launch app"
        if (cmd != "") return "Run: " cmd
        return ""
    }
    if (a ~ /hl\.dsp\.window\.close\(\)/) return "Close focused window"
    if (a ~ /hl\.dsp\.window\.pseudo\(\)/) return "Toggle pseudo-tiling"
    if (a ~ /hl\.dsp\.window\.drag\(\)/) return "Drag window (mouse)"
    if (a ~ /hl\.dsp\.window\.resize\(\)/) return "Resize window (mouse)"
    if (a ~ /hl\.dsp\.layout\("togglesplit"\)/) return "Toggle split layout"
    if (a ~ /hl\.dsp\.focus\(\{ direction = "left" \}\)/) return "Focus window left"
    if (a ~ /hl\.dsp\.focus\(\{ direction = "right" \}\)/) return "Focus window right"
    if (a ~ /hl\.dsp\.focus\(\{ direction = "up" \}\)/) return "Focus window up"
    if (a ~ /hl\.dsp\.focus\(\{ direction = "down" \}\)/) return "Focus window down"
    if (a ~ /hl\.dsp\.workspace\.toggle_special/) return "Toggle special workspace"
    if (a ~ /hl\.dsp\.exec_cmd\("hyprlock"\)/) return "Lock screen"
    if (a ~ /XF86AudioRaiseVolume/) return "Volume up"
    if (a ~ /XF86AudioLowerVolume/) return "Volume down"
    if (a ~ /XF86AudioMute/) return "Mute audio"
    if (a ~ /XF86AudioMicMute/) return "Mute microphone"
    if (a ~ /XF86MonBrightness/) return "Screen brightness"
    return ""
}

/hl\.bind\(/ {
    combo = ""
    if (match($0, /hl\.bind\(mainMod \.\. "([^"]+)"/, m)) {
        combo = "SUPER" m[1]
    } else if (match($0, /hl\.bind\("([^"]+)"/, m)) {
        combo = m[1]
    } else {
        next
    }
    # Skip the workspace for-loop binds (" + " with nothing after it).
    if (combo ~ /[+][[:space:]]*$/) { next }

    desc = ""
    # Inline trailing comment: `-- ...` after the closing paren of the call,
    # so `--` inside a command string is not mistaken for a comment.
    if (match($0, /\)[[:space:]]*--[[:space:]]*([^-].*)$/, m)) {
        desc = m[1]
    } else {
        desc = join_block()
        if (desc == "") {
            desc = action_label($0)
        }
    }

    if (desc != "") {
        printf "%s\t%s\n", combo, desc
    }
    block_len = 0
    last = ""
    next
}
