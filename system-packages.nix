# Declarative tracking of the system-level (root) packages on archeus.
#
# home-manager is user-scope only (it cannot install root packages), so the
# pacman-level package set is tracked here instead - the single source of
# truth for what a fresh install should install. Honest limit: this tracks
# names, not versions - packages float with pacman -Syu.
#
#   systemPackages  official Arch repositories (installed via pacman)
#   aurPackages     Arch User Repository       (installed via paru)
#
# Install with build/system-packages.sh. Reconcile this list against the box
# with `pacman -Qqen` (native) and `pacman -Qqem` (AUR).
# Seeded from archeus `pacman -Qqen` on 2026-08-06.
#
# The kernel (linux/linux-headers/linux-docs) is intentionally NOT listed:
# archeus runs a locally-rebuilt patched kernel that pacman must never
# overwrite (IgnorePkg in /etc/pacman.conf). A fresh install installs them as
# part of the patch workflow in docs/macbookpro12-1-keyboard-kernel-patch.md.
{
  systemPackages = [
    # Base / boot
    "base"
    "base-devel"
    "sudo"
    "grub"
    "efibootmgr"
    "intel-ucode"
    "btrfs-progs"
    "cryptsetup"
    "linux-firmware"
    # Kernel build / ACPI helpers
    "git"
    "pacman-contrib"
    "acpi_call-dkms"
    "acpica"
    "acpid"
    # Power management - D-Bus power profile API driven by build/power-profile.sh
    # (auto-switches power-saver/balanced on AC/battery).
    "power-profiles-daemon"
    # System daemons / network
    "networkmanager"
    "iwd"
    "openssh"
    "tailscale"
    "nix"
    "pciutils"
    "usbutils"
    "tmux"
    "zsh"
    "vim"
    "neovim"
    "fzf"
    "less"
    # Display server / desktop
    "hyprland"
    "hyprlock"
    "hypridle"
    "hyprpaper"
    "hyprsunset" # nightlight temperature filter (build/nightlight.sh)
    "hyprpolkitagent"
    "waybar"
    "mako"
    "wofi"
    "kitty"
    "thunar"
    "cliphist"
    "wl-clipboard"
    "xdg-desktop-portal"
    "xdg-desktop-portal-hyprland"
    # Audio
    "pipewire"
    "pipewire-audio"
    "pipewire-pulse"
    "wireplumber"
    "alsa-utils"
    # ALSA-only apps (e.g. Handy's cpal microphone capture) need ALSA's default
    # PCM to route through PipeWire; without this, opening "default" fails while
    # the raw hw device (plughw:1,0) still works.
    "pipewire-alsa"
    # Bluetooth
    "bluez"
    "bluez-utils"
    "blueman" # tray applet + manager GUI for connecting/pairing devices
    # Screenshots / tools
    "grim"
    "slurp"
    "swappy"
    "wf-recorder" # screen recording (build/record.sh)
    "tesseract" # OCR (build/ocr.sh)
    "tesseract-data-eng"
    "jq" # JSON parsing for hyprctl -j in build/ scripts
    "qrencode" # wifi share QR (build/network-qr.sh)
    "lazygit"
    "opencode"
    "brightnessctl"
    # Archives
    "unzip"
    # Ops / provisioning - ansible ships ansible-vault, used to decrypt the
    # MCP server secrets (see docs/opencode-secrets.md).
    "ansible"
    # Language toolchains - mason.nvim builds gopls from source (needs go) and
    # installs pyright, html-lsp and typescript-language-server via npm
    # (nodejs + npm); without these those LSP installs fail in nvim.
    # tree-sitter-cli is required by the nvim-treesitter main branch to build
    # parsers ("tree-sitter build").
    "go"
    "nodejs"
    "npm"
    "tree-sitter-cli"
    # Speech-to-text (Handy needs wtype to type on Wayland; the app itself is in AUR)
    "wtype"
  ];

  aurPackages = [
    "paru"
    "actkbd"
    "google-chrome"
    "handy-bin" # offline local-model speech-to-text (like macOS Handy); needs wtype on Wayland
    "ttf-meslo-nerd-font-powerlevel10k" # MesloLGS NF, for the bash prompt icons in kitty
    "ttf-press-start-2p" # retro 8-bit font (Atari-era glyphs), for the hyprlock clock
  ];
}
