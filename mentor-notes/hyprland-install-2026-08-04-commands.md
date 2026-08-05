# Commands run - Hyprland install session (2026-08-04)

Companion to `hyprland-install-2026-08-04.md`. One entry per command actually run, in order.

## `sudo pacman -Syu`
- What it does: syncs the package databases (`-y`) then upgrades every installed package that has a newer version available in the repos (`-u`).
- Args: `-S` sync operation, `-y` refresh databases, `-u` sysupgrade.
- Why we ran it: baseline check that the system is current before adding a new package (Hyprland) and its dependencies, so we're not debugging on a stale base.
- Note from this run: `linux`, `linux-docs`, `linux-headers` were reported as "local is newer than core" - this is a patched kernel already ahead of the repo version. Confirmed via `man pacman` that plain `-Syu` never downgrades; it only upgrades a package if the sync repo version is newer than local. Downgrades only happen with `-Syuu` (double `-u`), which was not used. Patched kernel was untouched.

## `lspci -k | grep -A 3 -i vga`
- What it does: `lspci` lists PCI devices; `-k` also shows the kernel driver bound to each device. Piped into `grep -A 3 -i vga` to isolate the graphics controller entry and the 3 lines after it (which include the driver info).
- Args: `-k` (kernel driver info), `-A 3` (3 lines of context after match), `-i` (case-insensitive match on "vga").
- Why we ran it: identify the GPU and its current driver before installing Hyprland, since Hyprland (Wayland) has known problems on NVIDIA that require extra setup, but works out of the box on Intel/AMD.
- Result: Intel Iris Graphics 6100 (Broadwell-U), driver `i915` already loaded. No NVIDIA-specific steps needed.
