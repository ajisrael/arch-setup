# Arch Linux Manual Installation Command Summary 

Arch Linux setup documentation for the MacBookPro12,1 that additionally
bakes in the fix for the internal keyboard/trackpad, so the internal
keyboard works at every stage: the GRUB menu, the LUKS passphrase prompt,
and the booted system. Companion to the
[learnlinux.tv 2026 Arch install guide](https://www.learnlinux.tv/arch-linux-installation-guide-2026-update/),
adjusted for this Mac's hardware (LUKS + Btrfs instead of LVM + ext4, no
GNOME/display packages, Mac-specific input driver notes). 

Why the keyboard needs these extra steps: see
`docs/macbookpro12-1-keyboard-spi-fix.md`.

Short version - this model's keyboard/trackpad controller is dual-mode
(USB or SPI, switched by ACPI GPIO methods `UIEN`/`UIST` and
`SIEN`/`SIST`). Apple's EFI firmware leaves the electrical switch on SPI
from power-on, but Linux's ACPI tables report USB active (`UIST=1`), so the
mainlined `applespi` driver backs off with "USB interface already enabled"
and nothing claims the keyboard. Forcing SPI mode fixes that first half;
but SPI transfers then time out because the LPSS DMA engine is held in
permanent reset by Apple's EFI firmware, so the SPI controller must be
forced into PIO (no-DMA) mode. The steps below install `acpi_call`, switch
the hardware to SPI mode before `applespi` loads, and force PIO.

IMPORTANT: the internal keyboard/trackpad are dead inside the live
`archiso` too (the fix is baked into the installed system, not the ISO), so
you need an external USB keyboard/mouse for the installation itself. The
internal keyboard starts working from the first boot of the installed
system. Note that this fix is MacBookPro12,1-specific - do not apply it to
other models (see the final section).

## Pre-Installation (in the live ISO)

Confirm you booted in UEFI mode - if this directory is empty, the later
GRUB EFI install will fail or silently do the wrong thing.

```bash
ls /sys/firmware/efi/efivars
```

Connect to wifi (skip if on Ethernet - check with `ip addr show` first).

```bash
iwctl
```

```bash
station wlan0 scan
```

```bash
station wlan0 get-networks
```

```bash
station wlan0 connect <SSID>
```

```bash
exit
```

If `iwctl` shows no `wlan0` device at all, or `rfkill list` shows the
wifi soft-blocked, that's a driver/firmware issue, not a config issue -
diagnose before continuing rather than fighting `iwctl`.

```bash
rfkill list
```

Verify the connection.

```bash
ping -c 3 archlinux.org
```

Sync the system clock - matters for TLS/package signature checks during
`pacstrap`.

```bash
timedatectl set-ntp true
```

---

## Partitioning and Filesystem Preparation

View current partitions - confirm the device name (`/dev/sda` on this Mac
under the archiso; NVMe disks would be `/dev/nvme0n1` instead).

```bash
lsblk
```

Create the GPT partition layout with an EFI partition and encrypted Linux
partition.

```bash
cfdisk /dev/sda
```

- Create a new `1G` partition and set the type to EFI System
- Create a partition for remaining space that is Linux filesystem
- Then write the partitions and quit the program

Format the EFI System Partition as FAT32.

```bash
mkfs.fat -F32 /dev/sda1
```

Create the LUKS encryption container on the Linux partition.

```bash
cryptsetup luksFormat /dev/sda2
```

Open the encrypted partition as cryptroot.

```bash
cryptsetup open /dev/sda2 cryptroot
```

Format the unlocked container as Btrfs.

```bash
mkfs.btrfs /dev/mapper/cryptroot
```

---

## Btrfs Subvolume Creation

Separate subvolumes let you snapshot `@` (root) without dragging `@home`,
`@var` (noisy log/cache churn), or `@snapshots` itself into every snapshot.

Mount the Btrfs filesystem temporarily to create subvolumes.

```bash
mount /dev/mapper/cryptroot /mnt
```

Create the root subvolume.

```bash
btrfs subvolume create /mnt/@
```

Create the home subvolume.

```bash
btrfs subvolume create /mnt/@home
```

Create the variable data subvolume.

```bash
btrfs subvolume create /mnt/@var
```

Create the log subvolume.

```bash
btrfs subvolume create /mnt/@log
```

Create the snapshots subvolume.

```bash
btrfs subvolume create /mnt/@snapshots
```

Unmount the temporary Btrfs mount.

```bash
umount /mnt
```

---

## Mounting the Installation Targets

Mount the root Btrfs subvolume.

```bash
mount -o subvol=@,compress=zstd,noatime /dev/mapper/cryptroot /mnt
```

`compress=zstd` enables transparent Btrfs compression (good default -
cheap CPU cost, meaningful space savings). `noatime` skips updating a
file's last-read timestamp on every access, which avoids extra writes on
every read - safe unless something you rely on reads that timestamp
(most tools use mtime, not atime).

Create mount points for additional filesystems.

```bash
mkdir -p /mnt/{boot,home,var,.snapshots}
```

Mount the home subvolume.

```bash
mount -o subvol=@home,compress=zstd,noatime /dev/mapper/cryptroot /mnt/home
```

Mount the var subvolume.

```bash
mount -o subvol=@var,compress=zstd,noatime /dev/mapper/cryptroot /mnt/var
```

Mount the log subvolume (needs its own explicit mount - the `mkdir -p`
above only created the empty directory, not a mount point).

```bash
mkdir /mnt/var/log
mount -o subvol=@log,compress=zstd,noatime /dev/mapper/cryptroot /mnt/var/log
```

Mount the snapshots subvolume.

```bash
mount -o subvol=@snapshots,compress=zstd,noatime /dev/mapper/cryptroot /mnt/.snapshots
```

Mount the EFI partition directly as /boot.

```bash
mount /dev/sda1 /mnt/boot
```

Verify all mounted filesystems before proceeding - catch a missed mount
now, not after `pacstrap` has already written files into the wrong place.

```bash
findmnt -R /mnt
```

---

## Installing the Base System

Install the Arch base system and essential packages. `openssh` is
included so you can immediately reach the machine remotely after first
boot, before any desktop environment or further config exists.

```bash
pacstrap -K /mnt base linux linux-headers linux-firmware btrfs-progs networkmanager openssh sudo vim git intel-ucode cryptsetup grub efibootmgr bluez bluez-utils acpid
```

| Package | Purpose |
|---|---|
| base | Minimal set of packages needed for a functional Arch system (coreutils, bash, systemd, pacman, etc). |
| linux | The Linux kernel (rolling release, tracks upstream closely). |
| linux-headers | Kernel headers, needed to build external kernel modules (DKMS packages, etc). |
| linux-firmware | Firmware blobs for hardware devices, including this Mac's Broadcom wifi chip. |
| btrfs-progs | Userspace tools to create and manage Btrfs filesystems and subvolumes. |
| networkmanager | Manages wired and wireless network connections after installation (includes wpa_supplicant as a dependency). |
| openssh | SSH client and server - the server lets you reach the machine remotely right after first boot. |
| sudo | Grants the primary user elevated privileges without logging in as root. |
| vim | Text editor, used throughout this guide to edit config files. |
| git | Version control, needed for cloning dotfiles/config repos post-install. |
| intel-ucode | Microcode updates for this Mac's Intel CPU, loaded early by the bootloader. |
| cryptsetup | Userspace tools to create and unlock the LUKS encrypted partition. |
| grub | Bootloader used to boot the encrypted, Btrfs-subvolumed system. |
| efibootmgr | Manages UEFI boot entries, used by grub-install. |
| bluez, bluez-utils | Bluetooth protocol stack and CLI utilities. |
| acpid | Handles ACPI events (lid close, power button, etc) on this laptop. |

Generate the filesystem table.

```bash
genfstab -U /mnt >> /mnt/etc/fstab
```

Enter the installed system environment.

```bash
arch-chroot /mnt
```

---

## System Configuration

Refresh the package signing keyring first, before anything else in this
section - `archlinux-keyring` ships as a `base` dependency, but the
version baked into `pacstrap` can be stale enough that installing an
older/archived package later (e.g. a downgrade from
archive.archlinux.org) fails with `invalid or corrupted package (PGP
signature)` even though the download itself is fine.

```bash
pacman -Sy archlinux-keyring
```

Set the timezone. List valid `<Region>/<City>` values with
`ls /usr/share/zoneinfo/` (regions) and `ls /usr/share/zoneinfo/<Region>`
(cities) - e.g. `America/New_York` or `Europe/London`. If unsure, cross-check
against `timedatectl list-timezones`.

```bash
ln -sf /usr/share/zoneinfo/<Region>/<City> /etc/localtime
```

Sync the hardware clock to it.

```bash
hwclock --systohc
```

Uncomment your locale (e.g. `en_US.UTF-8 UTF-8`) then generate it -
skipping this leaves the system in the bare `C` locale.

```bash
vim /etc/locale.gen
```

```bash
locale-gen
```

Persist the chosen locale.

```bash
echo "LANG=en_US.UTF-8" > /etc/locale.conf
```

Set the hostname.

```bash
echo "<hostname>" > /etc/hostname
```

Add the matching entry so the hostname resolves locally.

```bash
echo "127.0.1.1 <hostname>.localdomain <hostname>" >> /etc/hosts
```

Set the root password.

```bash
passwd
```

Create the primary user account.

```bash
useradd -m -g users -G wheel <username>
```

> `wheel` dates back to 1970s TOPS-20/BSD Unix, where only users in this
> group could `su` to root at all - the name reputedly comes from "big
> wheel," 70s slang for someone important. Today on Arch (and most
> distros) it has no special kernel/system meaning by itself - it's just a
> conventional group name that `visudo`'s default `%wheel ALL=(ALL:ALL)
> ALL` rule (uncommented below) grants sudo access to. Adding a user to
> `wheel` is what actually matters; the group's old absolute-gatekeeping
> role is now just convention carried forward.

Set the user password.

```bash
passwd <username>
```

Edit sudo permissions - uncomment `%wheel ALL=(ALL:ALL) ALL`.

```bash
EDITOR=vim visudo
```

Set up iwd as NetworkManager's wifi backend. The default backend
(wpa_supplicant) does not work on this machine, so install iwd, enable
it, and point NetworkManager at it before enabling NM itself.

```bash
pacman -S iwd
systemctl enable iwd
printf '[device]\nwifi.backend=iwd\n' > /etc/NetworkManager/conf.d/wifi-backend.conf
```

Enable networking at boot.

```bash
systemctl enable NetworkManager
```

Enable SSH so you can reach the machine remotely after reboot.

```bash
systemctl enable sshd
```

Enable time synchronization.

```bash
systemctl enable systemd-timesyncd
```

---

## Keyboard Fix Prerequisites (MacBookPro12,1 only)

This section installs the pieces that make the internal keyboard/trackpad
work via SPI + PIO. The Initramfs Configuration section directly after it
loads the SPI stack inside the initramfs so the keyboard works at the LUKS
prompt. Skip this section on models that are NOT MacBookPro12,1.

1. Install `acpi_call`, which lets Linux invoke ACPI methods - here the
   `SIEN(1)` call that switches the keyboard's electrical interface to
   SPI. It is in the official `extra` repo; the DKMS variant builds against
   the installed kernel (`linux-headers`, already in `pacstrap` above) and
   pulls in `gcc`/`make` as `dkms` dependencies automatically.

```bash
pacman -S acpi_call-dkms
```

2. If this disk previously held an install made with the OLD (now known to
   be wrong) advice in `docs/arch-setup-mac.md`, it may have an applespi
   blacklist left over - remove it. `applespi` and the `spi_pxa2xx_*` stack
   MUST be allowed to load on this model.

```bash
rm -f /etc/modprobe.d/blacklist-applespi.conf
```

3. Force the SPI controller into PIO mode by blacklisting the LPSS DMA
   driver. With no DMA device present, `spi-pxa2xx` automatically falls
   back to PIO (it logs `no DMA channels available, using PIO`). First
   confirm the DMA driver is actually a loadable module (must print 0; if
   it prints 1, `dw_dmac_pci` is built into the kernel and this blacklist
   won't help - see the [kernel-patch alternative](macbookpro12-1-keyboard-kernel-patch.md)):

```bash
grep -c dw_dmac_pci /usr/lib/modules/*/modules.builtin
```

   (Use the modules directory as written, not `$(uname -r)`: inside the
   chroot `uname -r` reports the host archiso kernel, whose version differs
   from the installed `linux` package's modules and so points nowhere.)

```bash
echo -e "blacklist dw_dmac_pci\nblacklist dw_dmac_core" > /etc/modprobe.d/blacklist-lpss-dma.conf
```

4. Switch the hardware to SPI mode before `applespi` ever probes, via a
   modprobe `install` reroute. This makes `SIEN(1)` run on every load of
   `applespi` - in the initramfs and in the booted system. It is the same
   pattern used to fix the MacBookAir 2015's identical controller.

   Note the DOUBLE backslash in the ACPI path. `modprobe.d` is parsed by
   kmod, which strips one level of escaping before the shell ever sees the
   command: `\_SB...` in the file arrives as the relative path `_SB...`,
   and `acpi_get_handle` rejects it with
   `acpi_call: Cannot get handle: Error: AE_BAD_PARAMETER` - so the reroute
   silently does nothing and the keyboard stays dead. `\\_SB...` in the
   file survives kmod's parsing as the absolute `\_SB...` the driver needs.
   (An interactive shell does NOT have this problem - only `modprobe.d`
   files.)

```bash
cat > /etc/modprobe.d/apple-keyboard-spi.conf <<'EOF'
install applespi /sbin/modprobe --ignore-install acpi_call 2>/dev/null; echo "\\_SB.PCI0.SPI1.SPIT.SIEN 1" > /proc/acpi/call 2>/dev/null; /sbin/modprobe --ignore-install applespi "$@"
EOF
```

5. Pin the SPI controller's runtime PM to always-on. The upstream PIO fix
   also fixed a runtime-PM bug where aggressive autosuspend causes PCIe
   Completion Timeouts on stock kernels; this udev rule applies that
   stopgap here (PCI device `0x9ce6` = the LPSS SPI controller at
   `00:15.4`). The `systemd` initramfs hook bundles `/etc/udev/rules.d`
   into the image, so this applies before the LUKS prompt too.

```bash
printf 'ACTION=="add", SUBSYSTEM=="pci", ATTR{device}=="0x9ce6", ATTR{power/control}="on"\n' > /etc/udev/rules.d/60-spi-pio.rules
```

Then continue to Initramfs Configuration - the `MODULES=` line there loads
`acpi_call`, the SPI host drivers, and `applespi` inside the initramfs, and
`mkinitcpio -P` rebuilds the image with everything above.

---

## Initramfs Configuration

Edit mkinitcpio configuration.

```bash
vim /etc/mkinitcpio.conf
```

Add the SPI keyboard stack to `MODULES=`. Keep `acpi_call` first, then the
SPI host drivers, then `applespi` - so the `SIEN(1)` mode switch has
already happened by the time `applespi` binds to the SPI device.

```bash
MODULES=(acpi_call spi_pxa2xx_platform spi_pxa2xx_pci applespi)
```

Leave the HOOKS line exactly as below - it is already correct and is NOT
changed by this variant:

```bash
HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block sd-encrypt filesystems fsck)
```

TODO: Wrap this note in a dropdown.
Why `MODULES=`, not HOOKS: the `keyboard` hook only bundles the USB/serio
HID modules, not the SPI stack - so the SPI modules must be pulled in via
`MODULES=`. The `modconf` hook (already in HOOKS) is what carries
`/etc/modprobe.d` into the image; that is how the `dw_dmac` blacklist and
the `applespi` `SIEN(1)` reroute apply inside the initramfs, before the
LUKS prompt.

Rebuild initramfs images.

```bash
mkinitcpio -P
```

---

## GRUB Bootloader Configuration

Get the LUKS partition's UUID - do not reuse a UUID from a previous
install, it's regenerated by every `luksFormat`.

```bash
blkid -s UUID -o value /dev/sda2
```

Edit GRUB kernel parameters.

```bash
vim /etc/default/grub
```

Add the LUKS and Btrfs root parameters to `GRUB_CMDLINE_LINUX` (not
`GRUB_CMDLINE_LINUX_DEFAULT`), using the UUID from above.

>`GRUB_CMDLINE_LINUX_DEFAULT` only applies to the normal boot entry -
>`GRUB_CMDLINE_LINUX` applies to every generated entry, including recovery
>mode. These parameters unlock and locate the root filesystem, so every
>entry needs them or recovery mode won't boot.

```bash
rd.luks.name=<UUID>=cryptroot root=/dev/mapper/cryptroot rootflags=subvol=@ rw
```

Install GRUB for UEFI with the EFI partition mounted at /boot.

```bash
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=grub_uefi --recheck
```

Also install to the removable/fallback EFI path
(`EFI/Boot/BOOTX64.EFI`) with `--removable`. Apple firmware doesn't always reliably retain
NVRAM boot entries added by `grub-install`/`efibootmgr` across reboots or
firmware updates - the fallback path is picked up by the firmware even if
the NVRAM entry gets dropped.

```bash
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=grub_uefi --recheck --removable
```

Generate the GRUB configuration file.

```bash
grub-mkconfig -o /boot/grub/grub.cfg
```

---

## Final Hardware Packages

Bluetooth and ACPI (`bluez`, `bluez-utils`, `acpid`) were already
installed by `pacstrap` above - this just enables them now that services
can be managed inside the chroot.

Enable Bluetooth support.

```bash
systemctl enable bluetooth
```

Enable laptop ACPI event handling.

```bash
systemctl enable acpid
```

ACPI events are hardware/firmware signals for things like closing the
lid, pressing the power/sleep buttons, or a thermal trip point being hit
- the kernel receives them, but `acpid` is the userspace daemon that lets
you actually react to them (e.g. suspend on lid-close, run a script on
power-button-press) via `/etc/acpi/events/` rules. Most desktop
environments now handle these directly through `systemd-logind` /
`UPower` without needing `acpid` at all - it mainly matters here for a
bare setup with no DE, or for custom handling logind doesn't cover.

---

## Leaving the Installer

Exit the chroot environment.

```bash
exit
```

Unmount all installed filesystems.

```bash
umount -R /mnt
```

Reboot into the new Arch installation.

```bash
reboot
```

---

## Keyboard and Trackpad Verification (after reboot)

On MacBookPro12,1 with the SPI fix applied above, the internal
keyboard/trackpad should work from the GRUB menu, at the LUKS passphrase
prompt, and in the booted system. Verify after first boot:

```bash
journalctl -k -b | grep -Ei 'applespi|pxa2xx|dmac'
```

Expect: `applespi` binding to `spi-APP000D:00` and registering "Apple SPI
Keyboard" / "Apple SPI Touchpad" input devices, and `spi-pxa2xx` logging
`no DMA channels available, using PIO` (DMA should be absent entirely). Do
NOT expect `SPI transfer timed out` / `Error reading from device: -110` -
if that loop appears, the PIO forcing failed (see fix doc, step "Verify the
PIO path is active").

```bash
lsmod | grep -E 'applespi|spi_pxa2xx|dw_dmac'
```

`dw_dmac*` should not be loaded. If the keyboard works after login but NOT
at the LUKS prompt, the `SIEN(1)` reroute did not fire inside the initramfs
- check the baked-in copy is the fixed one (see "Troubleshooting: keyboard
dead after boot" below; the kmod `modprobe.d` backslash trap is the usual
culprit, not hook ordering). Also confirm the image actually carries the
SPI stack - `acpi_call` is a DKMS module that `autodetect` cannot see, so
it only gets in via `MODULES=` (or an initcpio `add_module`); if it is
missing, nothing can run the reroute in the initramfs:

```bash
lsinitcpio /boot/initramfs-linux.img | grep -E 'acpi_call|applespi|spi-pxa2xx'
```

If `acpi_call` is absent, add it to `MODULES=` (keep the full
`MODULES=(acpi_call spi_pxa2xx_platform spi_pxa2xx_pci applespi)`) and
re-run `mkinitcpio -P`.

### Troubleshooting: keyboard dead after boot

If the internal keyboard/trackpad do not work at all after a reboot
(both at the LUKS prompt and in the system), check whether the SPI/USB
mux actually switched over. All of this needs root:

```bash
sudo su -
echo "\\_SB.PCI0.SPI1.SPIT.UIST" > /proc/acpi/call
cat /proc/acpi/call   # 0x1 = still on USB (broken)
echo "\\_SB.PCI0.SPI1.SPIT.SIST" > /proc/acpi/call
cat /proc/acpi/call   # 0x0 = SPI off (broken)
```

If `UIST` reads `0x1`, the mux was not switched before `applespi`
probed. The most likely cause is the reroute path being eaten by kmod's
`modprobe.d` parser - check `/etc/modprobe.d/apple-keyboard-spi.conf`
contains `\\_SB` (two backslashes), not `\_SB` (see step 4). A boot log
containing `acpi_call: Cannot get handle: Error: AE_BAD_PARAMETER` right
before the `applespi` bail-out is the signature of the mangled path. Fix
it live, as root:

```bash
echo "\\_SB.PCI0.SPI1.SPIT.SIEN 1" > /proc/acpi/call
cat /proc/acpi/call   # expect 0x1
echo "\\_SB.PCI0.SPI1.SPIT.SIST" > /proc/acpi/call
cat /proc/acpi/call   # expect 0x1

rmmod applespi && modprobe applespi
dmesg | tail
```

Expect `applespi: modeswitch done`, then `input: Apple SPI Keyboard` and
`input: Apple SPI Touchpad` (watch the short delay - the mode switch takes
a moment). If this works manually but the keyboard is dead after every
reboot, first verify the reroute file's escaping, then confirm the
initramfs actually contains the fixed file and that `mkinitcpio -P` was
re-run:

```bash
grep _SB /etc/modprobe.d/apple-keyboard-spi.conf   # must show \\_SB
lsinitcpio /boot/initramfs-linux.img | grep apple-keyboard
```

Benign noise you may see and can ignore during a manual reload: an
occasional `Received corrupted packet (crc mismatch)`, and
`Unknown touchpad model 3 - falling back to MB8 touchpad` (the trackpad
still works). A `Cannot get handle: Error: AE_BAD_PARAMETER` is NOT
benign at boot - it means the reroute path was mangled, fix the escaping.

This variant and its fixes are MacBookPro12,1-specific. On other models:

- MacBook8,1/9,1 (12" 2015) and Touch Bar-era MacBook Pros (2016+) wire the
  keyboard over SPI and use `applespi` with `spi_pxa2xx_platform` +
  `spi_pxa2xx_pci`/`intel_lpss_pci` - but their firmware does not
  mis-report the mode, so the `SIEN(1)` reroute and `dw_dmac` blacklist
  here are not needed.
- MacBookPro11,x (2013-15 15", no Touch Bar) wire it as plain internal USB
  and need no SPI handling at all.

---

## Connecting to Wifi (after reboot)

NetworkManager is enabled and running now (from the System Configuration
step above), so this replaces `iwctl` - `iwctl` only exists on the live
ISO's `iwd`-based setup, not on the installed system.

List available networks.

```bash
nmcli device wifi list
```

Connect, using the SSID from the list above.

```bash
nmcli device wifi connect <SSID> --ask
```

`--ask` prompts for the password interactively instead of putting it on
the command line (and in shell history). Verify the connection.

```bash
ping -c 3 archlinux.org
```

If `nmcli device wifi list` shows no networks, prefer the interactive
`nmtui` menu over troubleshooting `nmcli` flags directly - it's easier to
read the connection state and retry from.

```bash
nmtui
```

If the connection associates (`nmcli device status` briefly shows
`config`/`need-auth`) but then repeatedly disconnects and retries before
eventually failing with "Insufficient privileges" or a 90s timeout -
even with the correct password - this is a known `brcmfmac` issue on this
Mac's Broadcom BCM43602 chip: the card's power-management mode causes it
to drop out and miss the AP's WPA handshake frames. Check
`journalctl -u NetworkManager --since "10 min ago"` for a repeating
`associated -> disconnected` / "association took too long" pattern to
confirm this before assuming the password is wrong. Disable wifi
powersave to fix it.

```bash
printf "[connection]\nwifi.powersave = 2\n" | sudo tee /etc/NetworkManager/conf.d/wifi-powersave-off.conf
```

```bash
sudo systemctl restart NetworkManager
```

Then retry the `nmcli device wifi connect` command above.

If that still doesn't fix it and `journalctl -u NetworkManager` /
`journalctl -u wpa_supplicant` shows a clean association followed by
`Authentication ... timed out` and `CTRL-EVENT-DISCONNECTED ...
reason=3 locally_generated=1`, repeating - this is a known regression in
`wpa_supplicant` 2.11 affecting Broadcom wifi (`brcmfmac`/`wl` drivers),
not specific to this Mac. Confirmed via the Arch Linux bug thread
(bbs.archlinux.org/viewtopic.php?id=298025) with the identical log
signature.

Downgrading to `wpa_supplicant` 2:2.10-8 (the thread's workaround) is a
dead end on a fresh install - that build's signing key
(`heftig@archlinux.org`, fingerprint
`06687A1D9D4FAB08B50FD92B3B94A80E50A477C7`) has since been disabled in
Arch's keyring (confirmed via `pacman-key --finger`), and pacman
deliberately refuses disabled keys regardless of local signing - don't
work around this with `--no-verify`. Switch NetworkManager to the `iwd`
backend instead, which sidesteps `wpa_supplicant` entirely and is
confirmed working on this Mac's Broadcom BCM43602 chip.

```bash
sudo pacman -S iwd
```

```bash
sudo mkdir -p /etc/NetworkManager/conf.d
printf "[device]\nwifi.backend=iwd\n" | sudo tee /etc/NetworkManager/conf.d/wifi-backend.conf
```

```bash
sudo systemctl enable --now iwd
```

```bash
sudo systemctl restart NetworkManager
```

Then retry the `nmcli device wifi connect` command again. `wpa_supplicant`
itself can stay installed (NetworkManager just won't use it for wifi
anymore) or be removed if nothing else on the system depends on it.

```bash
sudo pacman -R wpa_supplicant
```

---

## Setup SSH

Once the machine has network access (wifi above, or Ethernet), set up SSH
keys so future logins don't need a password. The server side is already in
place - `openssh` was installed during the base install and `sshd` was
enabled in System Configuration above. Everything below runs on your
**local** machine, not on the Arch box.

Generate an ed25519 key pair if you don't already have one (skip if
`~/.ssh/id_ed25519.pub` already exists):

```bash
ssh-keygen -t ed25519
```

Copy the public key over. Prefer `ssh-copy-id` - it also sets the right
directory/file permissions on the remote side:

```bash
ssh-copy-id <user>@<arch-ip>
```

(If `ssh-copy-id` isn't installed on your local machine, the manual
equivalent is:)

```bash
cat ~/.ssh/<your_key_id>.pub | ssh <user>@<arch-ip> 'install -d -m700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys'
```

You'll be prompted for the password once during the copy. Afterwards,
logins are passwordless:

```bash
ssh <user>@<arch-ip>
```

If it still asks for a password, check the server side accepted the key
with `journalctl -u sshd -n 50` (look for `Accepted publickey` rather than
`Failed publickey`), and confirm `~/.ssh/authorized_keys` on the machine
has the right contents and permissions (`700` on `~/.ssh`, `600` on
`authorized_keys`).

---

## Pairing Bluetooth Devices (after reboot)

Bluetooth is enabled and running now (from the Final Hardware Packages
step above). `bluetoothctl` works either as a one-shot command per
action, or as an interactive shell - most keyboards/mice need the
interactive form because pairing requires displaying or exchanging a
passkey, which the one-shot form can't show you.

### Without the agent (works for simple devices, no passkey prompt)

Scan for nearby devices - `--timeout` stops the scan automatically
instead of needing a separate `scan off`.

```bash
bluetoothctl --timeout 15 scan on
```

List what was found, and note the target device's MAC address
(`XX:XX:XX:XX:XX:XX`).

```bash
bluetoothctl devices
```

Pair, trust, and connect.

```bash
bluetoothctl pair <MAC>
```

```bash
bluetoothctl trust <MAC>
```

```bash
bluetoothctl connect <MAC>
```

If `pair` fails with `org.bluez.Error.AuthenticationFailed` - common for
keyboards, which need a passkey typed on the device itself rather than a
plain tap-to-pair - use the interactive form with the agent enabled
instead.

### With the agent (needed for passkey-based devices like keyboards)

Enter the interactive shell.

```bash
bluetoothctl
```

Inside that shell (prompt changes to `[bluetooth]#`), enable the pairing
agent and make it the default - this is what lets a passkey prompt
appear instead of pairing silently failing.

```
agent on
default-agent
```

Pair, using the MAC address from `devices` above.

```
pair <MAC>
```

Watch for a passkey displayed on screen (type it on the target device
and press Enter there), or a yes/no confirmation prompt (answer `yes`
here in the terminal).

Once paired, still inside the same interactive shell:

```
trust <MAC>
connect <MAC>
```

Exit the interactive shell when done.

```
exit
```

Verify the connection - look for `Connected: yes`.

```bash
bluetoothctl info <MAC>
```
