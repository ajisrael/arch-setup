------------------
---- MONITORS ----
------------------

hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})


---------------------
---- MY PROGRAMS ----
---------------------

local terminal    = "kitty"
local fileManager = "thunar"
local menu        = "wofi --show drun"


-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function ()
    hl.exec_cmd("hyprpaper &")
    hl.exec_cmd("waybar &")
    hl.exec_cmd("mako &")
    hl.exec_cmd("hyprpolkitagent &")
    hl.exec_cmd("wl-paste --watch cliphist store &")
    -- Bluetooth: blueman-applet lives in the waybar tray (click = device
    -- menu, right-click = full manager). Replaces the old waybar bluetooth
    -- module + wofi picker script.
    hl.exec_cmd("blueman-applet &")
    -- Handy speech-to-text daemon. --start-hidden keeps the main window closed
    -- (it lives in the tray; the transcribe toggle is bound in KEYBINDINGS below).
    hl.exec_cmd("handy --start-hidden &")
    hl.exec_cmd("hypridle &")
    -- Power profile: pick power-saver/balanced for the current AC/battery state.
    -- The udev rule (config/udev/rules.d/90-power-profile.rules) re-applies it
    -- on plug/unplug; this line covers the boot/login case.
    hl.exec_cmd("/home/ajisrael/arch-setup/build/power-profile.sh &")
end)


-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")


-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
    general = {
        gaps_in  = 5,
        gaps_out = 20,

        border_size = 2,

        col = {
            -- Campfire gradient: warm Charmander-orange -> Pikachu-yellow for the
            -- focused window, matching the fire glow in pkmn-night-bg.png.
            active_border   = { colors = {"rgba(ff9e64ee)", "rgba(e0af68ee)"}, angle = 45 },
            -- Icy muted purple-blue for unfocused windows (snowy night sky).
            inactive_border = "rgba(565f89aa)",
        },

        resize_on_border = false,
        allow_tearing    = false,

        layout = "dwindle",
    },

    decoration = {
        rounding       = 12,
        rounding_power = 2,

        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = 0xbb1a1b26, -- deep Tokyo Night indigo, softer than pure black
        },

        blur = {
            enabled  = true,
            size     = 5,
            passes   = 2,     -- higher passes keep the frost looking clean at size 5
            vibrancy = 0.1696, -- subtle saturation lift, avoids the icy look going flat
        },
    },

    animations = {
        enabled = true,
    },
})

-- Waybar is a layer surface, so the frosted-glass backdrop comes from a layer
-- rule (window rules don't reach it). The translucent rgba() bar background in
-- style.css then gets blurred over whatever wallpaper is behind it.
hl.layer_rule({
    name  = "blur-waybar",
    match = { namespace = "waybar" },

    blur = true,
})

hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1}    } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}    } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}       } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1}    } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}     } })

hl.curve("easy",           { type = "spring", mass = 1, stiffness = 238.1191, dampening = 24.21279333 })

hl.animation({ leaf = "global",        enabled = true,  speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true,  speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true,  speed = 4.79, spring = "easy" })
hl.animation({ leaf = "windowsIn",     enabled = true,  speed = 4.1,  spring = "easy",         style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true,  speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true,  speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true,  speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true,  speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true,  speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true,  speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true,  speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true,  speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true,  speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true,  speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn",  enabled = true,  speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true,  speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "zoomFactor",    enabled = true,  speed = 7,    bezier = "quick" })

hl.config({
    dwindle = {
        preserve_split = true,
    },
})

hl.config({
    master = {
        new_status = "master",
    },
})

hl.config({
    scrolling = {
        fullscreen_on_one_column = true,
    },
})


----------------
----  MISC  ----
----------------

hl.config({
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
    },
})


---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout  = "us",
        kb_variant = "",
        kb_model   = "",
        kb_options = "",
        kb_rules   = "",

        follow_mouse = 0,

        sensitivity = 0,

        touchpad = {
            natural_scroll = true,
            tap_to_click   = false,
            scroll_factor  = 0.5, -- halve scroll speed; the stock 1.0 was too sensitive
        },
    },
})

hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace"
})


---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER"

-- Mac-like bindings: Super+C/V copy/paste, Super+Q quit, Super+T terminal.
-- Copy/paste synthesize Ctrl+C/Ctrl+V into the focused window via wtype, since
-- Wayland has no global clipboard shortcut (apps still see their native binding).
hl.bind(mainMod .. " + Q", hl.dsp.window.close()) -- quit: close the focused window
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("wtype -M ctrl c"))
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("wtype -M ctrl v"))
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd(menu)) -- Spotlight-style app launcher
-- Speech-to-text toggle (Handy). Wayland forbids apps from grabbing global
-- hotkeys, so Hyprland owns Alt+Space and tells the background Handy daemon to
-- start/stop transcribing via its CLI IPC.
hl.bind("ALT + SPACE", hl.dsp.exec_cmd("handy --toggle-transcription"))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + SHIFT + J", hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.exec_cmd("hyprlock"))
-- Capture suite: Super+Shift+S screenshot (region/swappy), +R recording
-- toggle, +O OCR-to-clipboard.
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("/home/ajisrael/arch-setup/build/screenshot.sh"))
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("/home/ajisrael/arch-setup/build/record.sh"))
hl.bind(mainMod .. " + SHIFT + O", hl.dsp.exec_cmd("/home/ajisrael/arch-setup/build/ocr.sh"))
-- Nightlight: Super+Shift+N toggles the warm 4000K hyprsunset filter.
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd("/home/ajisrael/arch-setup/build/nightlight.sh toggle"))
-- Browser: Super+B focuses an open Chrome window, else starts Chrome.
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("/home/ajisrael/arch-setup/build/launch-or-focus.sh google-chrome google-chrome"))
-- Wi-Fi share QR: Super+W notifies with the current network's QR (join with a phone).
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("/home/ajisrael/arch-setup/build/network-qr.sh --png"))
-- Window toggles: gaps (Super+G), tiled fullscreen (Super+F), transparency on
-- the focused window (Super+Shift+I), single-window 1:1 aspect (Super+Shift+F),
-- pop-out float (Super+Shift+P), close every window (Super+Shift+Q).
-- Width save/restore lives in build/window.sh (width-save / width-restore);
-- no default binds (MacBook keyboard has no Home key).
hl.bind(mainMod .. " + G", hl.dsp.exec_cmd("/home/ajisrael/arch-setup/build/window.sh gaps"))
hl.bind(mainMod .. " + F", hl.dsp.exec_cmd("/home/ajisrael/arch-setup/build/window.sh fullscreen"))
hl.bind(mainMod .. " + SHIFT + I", hl.dsp.exec_cmd("/home/ajisrael/arch-setup/build/window.sh transparency"))
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.exec_cmd("/home/ajisrael/arch-setup/build/window.sh square"))
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd("/home/ajisrael/arch-setup/build/window.sh pop"))
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.exec_cmd("/home/ajisrael/arch-setup/build/window.sh close-all"))
-- Keybinding cheatsheet: Super+SLASH opens the bind list in wofi.
hl.bind(mainMod .. " + SLASH", hl.dsp.exec_cmd("/home/ajisrael/arch-setup/build/keybindings.sh"))

hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Vim-style focus navigation
hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "down" }))
hl.bind(mainMod .. " + K", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + L", hl.dsp.focus({ direction = "right" }))

for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))
-- Super+Shift+S is the screenshot bind above

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
-- Audio sink switching: Super+A cycles the default output, Super+Shift+A
-- restarts the audio stack (recovery when a device wedges).
hl.bind(mainMod .. " + A",      hl.dsp.exec_cmd("/home/ajisrael/arch-setup/build/audio-sink-cycle.sh"))
hl.bind(mainMod .. " + SHIFT + A", hl.dsp.exec_cmd("/home/ajisrael/arch-setup/build/restart-audio.sh"))
-- Screen brightness (XF86MonBrightnessUp/Down) is handled by actkbd globally
-- (config/actkbd/actkbd.conf) - binding it here too would double-step.


--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

local suppressMaximizeRule = hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})

hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})

hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },

    move  = "20 monitor_h-120",
    float = true,
})
