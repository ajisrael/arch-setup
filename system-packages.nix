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
    # System daemons / network
    "networkmanager"
    "iwd"
    "openssh"
    "tailscale"
    "nix"
    "pciutils"
    "usbutils"
    "tmux"
    "vim"
    "less"
    # Display server / desktop
    "hyprland"
    "hyprlock"
    "hypridle"
    "hyprpaper"
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
    # Bluetooth
    "bluez"
    "bluez-utils"
    # Screenshots / tools
    "grim"
    "slurp"
    "swappy"
    "lazygit"
    "opencode"
    "brightnessctl"
  ];

  aurPackages = [
    "paru"
    "actkbd"
    "google-chrome"
    "ttf-meslo-nerd-font-powerlevel10k" # MesloLGS NF, for the bash prompt icons in kitty
  ];
}
