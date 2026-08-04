# MacBookPro12,1 Keyboard/Trackpad Next Diagnostics

## Purpose

This document is a follow-up to `docs/macbookpro12-1-keyboard-issue.md`.
It summarizes the extra source review done against the local Linux clone
in `~/examples/linux`, records the most useful code paths to inspect, and
lists additional diagnostic options for understanding why the internal
keyboard and trackpad work in firmware/bootloaders but not after Linux
takes ownership.

## Current read of the problem

The strongest path to pursue is still the USB path, not the SPI path.

The MacBookPro12,1 internal keyboard/trackpad controller is dual-mode, but
mainline Linux treats this model primarily as a USB Wellspring device:

- `applespi.c` says MacBookPro12 has both USB and SPI wiring available.
- The original `applespi` upstream commit and Kconfig help text target
  `MacBook8,1+` and `MacBookPro13,*` / `MacBookPro14,*`, not
  `MacBookPro12,*`.
- `bcm5974.c` explicitly added MacBookPro12,1 USB touchpad support in
  commit `d58069265c9d`.
- The MacBookPro12,1 USB IDs are Wellspring9: `05ac:0272`,
  `05ac:0273`, and `05ac:0274`.

The observed Linux failure happens before `bcm5974`, `hid_apple`, or any
other USB device driver can bind: `usb1-port5` is powered, but xHCI never
reports Current Connect Status. That points at xHCI ownership, routing,
reset, or firmware handoff state rather than a normal input-driver issue.

SPI mode remains useful as a controlled experiment because calling
`SIEN(1)` changes the hardware mode and allows `applespi` to bind. But
because actual SPI transfers then time out, simply patching `applespi` to
ignore `UIST` is unlikely to be sufficient by itself.

## Linux Source Reference Paths

All paths below are relative to the Linux repo root.

### Apple SPI Driver

- `drivers/input/keyboard/applespi.c`

Important sections:

- Top-of-file comment: describes the USB/SPI dual-mode design and
  `UIEN`/`UIST`/`SIEN`/`SIST`.
- `applespi_get_spi_settings()`: reads Apple ACPI properties
  `spiCSDelay`, `resetA2RUsec`, and `resetRecUsec`.
- `applespi_enable_spi()`: calls `SIEN(1)` if SPI is not already active,
  then waits 50 ms.
- `applespi_probe()`: checks `UIST`; if USB is active, logs
  `USB interface already enabled` and returns `-ENODEV` before allocating
  driver state.
- ACPI ID table near the bottom: matches `APP000D`.

Relevant source/history notes:

- Upstream commit adding the driver:
  `038b1a05eae6 Input: add Apple SPI keyboard and trackpad driver`
- The commit message says the SPI driver targets recent `MacBook8,1+`
  and `MacBookPro13,*` / `MacBookPro14,*`, not `MacBookPro12,*`.

### Apple USB Trackpad Driver

- `drivers/input/mouse/bcm5974.c`

Important sections:

- Wellspring USB ID definitions near the top.
- `USB_DEVICE_ID_APPLE_WELLSPRING9_ANSI`, `_ISO`, and `_JIS` are the
  MacBookPro12,1 IDs: `0x0272`, `0x0273`, `0x0274`.
- `bcm5974_table`: confirms those IDs are intended to bind to this USB
  driver.
- `bcm5974_config_table`: contains the MacBookPro12,1 TYPE4 device
  configuration.
- `bcm5974_wellspring_mode()`: sends USB control messages to switch the
  device into Wellspring mode once it has enumerated.
- `bcm5974_mode_reset_work()`: newer recovery path for failed mode
  switches.

Relevant source/history notes:

- MacBookPro12,1 support commit:
  `d58069265c9d Input: bcm5974 - add support for the 2015 Macbook Pro`
- Mode-switch recovery commit:
  `fc1e8a6f129d Input: bcm5974 - recover from failed mode switch`

### Apple HID Quirks

- `drivers/hid/hid-ids.h`
- `drivers/hid/hid-apple.c`
- `drivers/hid/hid-quirks.c`

Important sections:

- Wellspring9 USB IDs are also defined in `hid-ids.h`.
- `hid-quirks.c` contains Apple Wellspring entries so generic HID does
  not claim devices that should be handled by Apple-specific drivers.
- These files matter only after USB enumeration. Since this machine never
  gets `CCS=1` on the keyboard/trackpad port, they are not the first
  failure point.

### xHCI PCI Driver

- `drivers/usb/host/xhci-pci.c`

Important sections:

- Device ID definition:
  `PCI_DEVICE_ID_INTEL_WILDCATPOINT_LP_XHCI 0x9cb1`
- `xhci_pci_quirks()`: applies generic Intel xHCI quirks.
- For Wildcat Point-LP (`0x9cb1`), Linux currently applies
  `XHCI_SPURIOUS_REBOOT` and `XHCI_SPURIOUS_WAKEUP`.
- No MacBookPro12,1-specific xHCI quirk was found.
- Potential experimental quirks to test carefully:
  `XHCI_RESET_ON_RESUME`, `XHCI_RESET_TO_DEFAULT`,
  `XHCI_DEFAULT_PM_RUNTIME_ALLOW`, or suppressing one reset path.

### xHCI Early Handoff and Intel Port Routing

- `drivers/usb/host/pci-quirks.c`

Important sections:

- `quirk_usb_early_handoff()`: generic early PCI USB handoff.
- `quirk_usb_handoff_xhci()`: xHCI BIOS/OS ownership transfer.
- `usb_enable_intel_xhci_ports()`: Intel-specific USB port routing.

This is one of the highest-value files for this bug. For Intel xHCI,
Linux reads the port routing masks and writes routing registers:

- `USB_INTEL_XUSB2PR` at PCI config offset `0xd0`
- `USB_INTEL_USB2PRM` at PCI config offset `0xd4`
- `USB_INTEL_USB3_PSSEN` at PCI config offset `0xd8`
- `USB_INTEL_USB3PRM` at PCI config offset `0xdc`

Because the failed keyboard/trackpad path is an internal USB2 high-speed
port (`HS05`), bit 5 of the USB2 routing state is especially interesting.

### xHCI Core and Hub Handling

- `drivers/usb/host/xhci.c`
- `drivers/usb/host/xhci-hub.c`
- `drivers/usb/host/xhci-ring.c`
- `drivers/usb/core/hub.c`

Important sections:

- `xhci.c`: controller reset, startup, suspend, resume, and reset quirk
  behavior.
- `xhci-hub.c`: xHCI root hub port status handling and `PORTSC` reads.
- `xhci-ring.c`: event ring processing for connect/disconnect events.
- `hub.c`: USB core hub state machine and enumeration flow.

These are the right files for dynamic debug once the routing state has
been captured.

### Apple Machine Detection and Existing Apple Quirks

- `arch/x86/kernel/quirks.c`
- `arch/x86/kernel/early-quirks.c`
- `drivers/acpi/x86/apple.c`

Important sections:

- `arch/x86/kernel/quirks.c`: defines and exports `x86_apple_machine`.
- `arch/x86/kernel/early-quirks.c`: contains an Apple AirPort early reset
  quirk for firmware-left-on hardware.
- `drivers/acpi/x86/apple.c`: extracts Apple ACPI `_DSM` properties.

There is no comparable Apple early quirk for MacBookPro12,1 internal
keyboard USB state in current mainline.

### ACPI SPI Device Creation

- `drivers/spi/spi.c`
- `drivers/spi/spi-pxa2xx.c`
- `drivers/spi/spi-pxa2xx-pci.c`
- `drivers/spi/spi-pxa2xx-platform.c`
- `drivers/mfd/intel-lpss.c`

Important sections:

- `drivers/spi/spi.c`: `acpi_spi_parse_apple_properties()` and
  `acpi_spi_device_alloc()`.
- Apple-specific SPI ACPI properties include `spiSclkPeriod`,
  `spiWordSize`, `spiBitOrder`, `spiSPO`, and `spiSPH`.
- `drivers/spi/spi-pxa2xx-pci.c`: LPT/Wildcat Point PCI glue for
  `0x9ce5` / `0x9ce6` SPI controllers.
- `drivers/spi/spi-pxa2xx.c`: actual transfer setup, speed calculation,
  PIO/DMA selection, and transfer timeout path.
- `drivers/mfd/intel-lpss.c`: Intel LPSS power/reset/private register
  handling.

These matter for the forced-SPI experiment, especially if testing whether
DMA/IOMMU timing is causing the `SPI transfer timed out` loop.

## Recommended Next Experiments

### 1. Capture Intel USB routing registers in Linux

Run this after booting Linux:

```bash
sudo setpci -s 00:14.0 d0.l d4.l d8.l dc.l
```

Command Breakdown:
    - `sudo`: Grants administrative privileges. This is strictly required to read direct hardware registers via the PCI configuration space.
    - `setpci`: A utility used to configure and query PCI devices.
    - `-s 00:14.0`: Targets the specific device located at bus 00, device 14, function 0 (typically the Intel USB xHCI controller)
    - `.d0.l d4.l d8.l dc.l`: Specifies the exact register offsets to read.The letters d0, d4, d8, and dc represent hexadecimal register addresses.The suffix .l (long) tells the tool to read a 32-bit double-word (4 bytes) at each location.

Output:
```bash
000007ff
000004ff
0000000f
0000000f
```


```bash
sudo lspci -s 00:14.0 -vvv -xxx
```

Command Breakdown:
    - `sudo`: Runs the command with administrative privileges. This is required because the -xxx flag reads sensitive system registers that standard users cannot access.
    - `lspci`: The core utility used to list all PCI (Peripheral Component Interconnect) devices in your system.
    - `-s 00:14.0`: Targets a specific device using its Bus:Device.Function address. In this case, it targets bus 00, device 14, function 0. On many modern Intel systems, this specific address corresponds to the USB xHCI Controller.
    - -`vvv`: Enables maximum verbosity. It forces the tool to extract and display every piece of readable data, power management capability, and operational status the device can report.
    - `-xxx`: Dumps the raw PCI configuration space in hexadecimal format. This includes both the standard 64-byte header and the extended 4096-byte PCI Express configuration space.

Output:
```bash
00:14.0 USB controller: Intel Corporation Wildcat Point-LP USB xHCI Controller (rev 03) (prog-if 30 [XHCI])
	Subsystem: Intel Corporation Device 7270
	Control: I/O- Mem+ BusMaster+ SpecCycle- MemWINV- VGASnoop- ParErr- Stepping- SERR- FastB2B- DisINTx+
	Status: Cap+ 66MHz- UDF- FastB2B+ ParErr- DEVSEL=medium >TAbort- <TAbort- <MAbort- >SERR- <PERR- INTx-
	Latency: 0
	Interrupts: pin B disabled, MSI(X) routed to IRQ 51-55
	Region 0: Memory at c1800000 (64-bit, non-prefetchable) [size=64K]
	Capabilities: [70] Power Management version 2
		Flags: PMEClk- DSI- D1- D2- AuxCurrent=375mA PME(D0-,D1-,D2-,D3hot+,D3cold+)
		Status: D0 NoSoftRst+ PME-Enable- DSel=0 DScale=0 PME-
	Capabilities: [80] MSI: Enable+ Count=8/8 Maskable- 64bit+
		Address: 00000000fee00418  Data: 0000
	Kernel driver in use: xhci_hcd
	Kernel modules: xhci_pci
00: 86 80 b1 9c 06 04 90 02 03 30 03 0c 00 00 00 00
10: 04 00 80 c1 00 00 00 00 00 00 00 00 00 00 00 00
20: 00 00 00 00 00 00 00 00 00 00 00 00 86 80 70 72
30: 00 00 00 00 70 00 00 00 00 00 00 00 00 01 00 00
40: fd 01 36 80 89 c6 0f 80 00 00 00 00 00 00 00 00
50: 5f 2e ce 0f 00 00 00 00 00 00 00 00 00 00 00 00
60: 30 20 00 00 00 00 00 00 00 00 00 00 00 00 00 00
70: 01 80 c2 c1 08 00 00 00 00 00 00 00 00 00 00 00
80: 05 00 b7 00 18 04 e0 fe 00 00 00 00 00 00 00 00
90: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
a0: 40 01 04 00 00 18 00 00 8f 20 02 00 00 00 00 00
b0: 01 00 00 00 02 00 00 00 00 00 00 00 00 00 00 00
c0: 01 00 00 00 02 00 00 00 00 00 00 00 00 00 00 00
d0: ff 07 00 00 ff 04 00 00 0f 00 00 00 0f 00 00 00
e0: 00 08 00 00 00 00 00 00 00 00 00 00 d8 d8 08 00
f0: 00 00 00 00 00 00 00 00 b1 0f 03 08 00 00 00 00
```

Interpretation:

- `0xd0` is `XUSB2PR`, the active USB2 xHCI routing register.
- `0xd4` is `XUSB2PRM`, the mask of USB2 ports Linux is allowed to
  route.
- `0xd8` is `USB3_PSSEN`, the active USB3 routing/termination register.
- `0xdc` is `USB3PRM`, the USB3 routing mask.

For `HS05`, bit 5 is the interesting bit in the USB2 values. If the
firmware and Linux disagree on that bit, this becomes a concrete xHCI
handoff/routing bug rather than a vague "keyboard does not enumerate"
bug.

### 2. Capture the same routing registers before Linux boots

From GRUB shell:

```text
insmod lspci
lspci
insmod setpci
setpci -s 00:14.0 d0.l
setpci -s 00:14.0 d4.l
setpci -s 00:14.0 d8.l
setpci -s 00:14.0 dc.l
```

Output:

```bash
grub> insmod lspci
grub> lspci
00:00.0 8086:1604 [0600] Host Bridge
00:02.0 8086:162b [0300] VGA Controller
00:03.0 8086:160c [0403] Multimedia device
00:14.0 8086:9cb1 [0c03] USB Controller [PI 30]
00:15.0 8086:9ce0 [0801] System hardware [PI 02]
00:15.4 8086:9ce6 [0c80] Serial Bus Controller
00:16.0 8086:9cba [0780] Communication controller
00:1b.0 8086:9ca0 [0403] Multimedia device
00:1c.0 8086:9c90 [0604] PCI-PCI Bridge
00:1c.1 8086:9c92 [0604] PCI-PCI Bridge
00:1c.2 8086:9c94 [0604] PCI-PCI Bridge
00:1c.4 8086:9c98 [0604] PCI-PCI Bridge
00:1c.5 8086:9c9a [0604] PCI-PCI Bridge
00:1f.0 8086:9cc3 [0601] ISA Bridge
00:1f.3 8086:9ca2 [0c05] Serial Bus Controller
00:1f.6 8086:9ca4 [1180] Unknown Data Input System
02:00.0 14e4:1570 [0480] Multimedia device
03:00.0 14e4:43ba [0280] Network controller
04:00.0 144d:a801 [0106] SATA Controller [PI 01]
05:00.0 8086:156d [0604] PCI-PCI Bridge
06:00.0 8086:156d [0604] PCI-PCI Bridge
06:03.0 8086:156d [0604] PCI-PCI Bridge
06:04.0 8086:156d [0604] PCI-PCI Bridge
06:05.0 8086:156d [0604] PCI-PCI Bridge
06:06.0 8086:156d [0604] PCI-PCI Bridge
07:00.0 8086:156c [0880] System hardware
grub> insmod setpci
grub> setpci -s 00:14.0 d0.1
Register d0 of 0:14.0 is 7ff
grub> setpci -s 00:14.0 d4.1
Register d4 of 0:14.0 is 4ff
grub> setpci -s 00:14.0 d8.1
Register d8 of 0:14.0 is f
grub> setpci -s 00:14.0 dc.1
Register dc of 0:14.0 is f
grub> _
```


If GRUB lacks `setpci`, use a UEFI Shell launched from rEFInd. UEFI Shell
usually provides:

```text
pci
pci 00 14 00 -i
```

It also provides `mm` for PCI/MMIO reads, but use read-only commands
first. Do not write PCI or MMIO state until the relevant register layout
is known.

#### 3. Capture xHCI `PORTSC` before and after Linux reset

**What this means:**
`PORTSC` (Port Status and Control) is a hardware register that acts as a status dashboard for a single USB port. It tells us if the port has power (`PP`), if a device is physically connected (`CCS`), and what state the connection is in. We want to check this register for port 5 (`HS05`) before Linux boots (when the keyboard works) and after Linux boots (when it fails). 

Because the USB routing (checked in steps 1 and 2) is identical, Linux is likely resetting the controller in a way that drops the port's connection. Checking `PORTSC` proves whether the port is losing power or just getting stuck trying to connect.

#### How to read `PORTSC` in Linux (After boot)
Instead of manually doing memory math, the Linux kernel has a debug feature that formats this for us.
Run this command:
```bash
sudo cat /sys/kernel/debug/usb/xhci/0000:00:14.0/ports/port05/portsc
```
**Result:** `0x000002a0 Speed=0 Link=RxDetect PP`
This means the port has power (`PP`) but is stuck scanning for a device (`RxDetect`) and doesn't actually see a connection (`CCS` is 0).

#### How to read `PORTSC` before Linux (Pre-boot)
Apple's EFI firmware is notoriously non-standard, which causes generic UEFI shells to freeze and crash the firmware (indicated by a flashing keyboard backlight). 

Instead of fighting with the UEFI shell, we can simply use the GRUB shell which we already know works fine! GRUB has a built-in command specifically for reading memory.

1. Reboot your computer.
2. In the rEFInd menu, select the **Arch Linux (GRUB)** entry.
3. When the GRUB boot menu appears, press the **`c`** key to enter the GRUB command line (`grub>`).
4. Read the memory address for Port 5 (`0xc18004c0` = BAR0 `0xc1800000` + CAPLENGTH `0x80` + offset `0x440`) by running:
   ```text
   read_dword 0xc18004c0
   ```
**Result:** `0x2a0`

#### Conclusion for Section 3:
The pre-boot `PORTSC` value (`0x2a0`) is exactly the same as the Linux value. This confirms that `CCS` (Current Connect Status) is `0` even when the keyboard is working perfectly in GRUB. Because there are no EHCI controllers visible on the PCI bus, and this xHCI port is entirely disconnected, this strongly implies the keyboard is not communicating over USB during boot; it must be using the SPI bus.

#### Verifying SPI Activity in GRUB (Pre-boot)
To definitively prove that the keyboard is functioning over SPI in GRUB, we checked the status of the Intel LPSS SPI Controller (PCI device `00:15.4`) directly from the GRUB shell:

1. Check the **Command Register** (Offset `0x04`) to see if the firmware enabled it:
   ```text
   setpci -s 00:15.4 04.w
   ```
   **Result:** `6` (This `0x06` means the Memory Space Enable and Bus Master bits are flipped ON, proving the Apple firmware actively initialized it).

2. Check the **Memory Address (BAR0)** (Offset `0x10`) to confirm it is mapped in RAM:
   ```text
   setpci -s 00:15.4 10.l
   ```
   **Result:** `c1819000` (A valid MMIO memory address is assigned).

**Final Conclusion:** The keyboard is definitively operating in SPI mode during the boot process.
### 4. Test whether Linux handoff/reset is breaking firmware-owned state (DEBUNKED)

**Status:** Debunked and Skipped.

**Reasoning:**
The original theory was that Linux aggressively resetting the xHCI (USB) controller during boot was knocking the keyboard offline. However, the results from Section 3 prove that the keyboard's USB connection is *already* offline (`CCS=0` and `RxDetect`) before Linux even touches it. 

Because the keyboard is not active on the xHCI USB bus during boot, the Linux xHCI reset cannot be the cause of the breakage. Attempting to apply Linux kernel xHCI quirks (like `XHCI_RESET_ON_RESUME` or `XHCI_RESET_TO_DEFAULT`) will have no effect on a device that isn't connected to the bus. We must abandon USB troubleshooting and focus on the SPI interface.

### 5. Instrument SPI mode as a separate branch

After manually switching to SPI with `SIEN(1)`, capture:

```bash
cat /sys/bus/spi/devices/spi-APP000D:00/modalias
cat /sys/bus/spi/devices/spi-APP000D:00/max_speed_hz
cat /sys/bus/spi/devices/spi-APP000D:00/bits_per_word
cat /proc/interrupts | grep -E 'spi|pxa|APP000D'
```

Enable dynamic debug for:

```text
drivers/input/keyboard/applespi.c
drivers/spi/spi.c
drivers/spi/spi-pxa2xx.c
drivers/spi/spi-pxa2xx-pci.c
drivers/mfd/intel-lpss.c
```

The SPI-specific questions are:

- What speed, mode, and bits-per-word did Linux actually apply?
- Is the SPI controller using DMA or PIO?
- Does forcing PIO avoid the transfer timeout?
- Do SPI IRQ counts move when typing or during the timeout loop?
- Are LPSS runtime PM transitions suspending the controller too early?

If forcing PIO changes the failure, then the problem may be DMA/IOMMU
ordering rather than `applespi` protocol logic.

## Bootloader Handshake Notes

The internal keyboard working in GRUB and rEFInd does not necessarily mean
those bootloaders know a special keyboard protocol. More likely, Apple EFI
firmware is still servicing USB input through firmware-owned xHCI state.
Linux then performs xHCI handoff and owns the controller directly.

That makes these states worth comparing across firmware, bootloader, and
Linux:

- xHCI BIOS-owned and OS-owned bits in the xHCI legacy capability.
- Intel USB2 routing registers `XUSB2PR` and `XUSB2PRM`.
- Port 5 `PORTSC`, especially `PP`, `CCS`, and change bits.
- ACPI `UIST` and `SIST`.
- Whether `HS05` is routed differently after choosing the disk through
  Apple's Option boot picker, GRUB, rEFInd, or UEFI Shell.

rEFInd can chain through UEFI Shell scripts before launching Linux. That
could eventually be used to record or alter PCI/MMIO state pre-boot, but
the first step should be read-only capture.

## Practical Priority Order

1. Compare `XUSB2PR`/`XUSB2PRM` from GRUB or UEFI Shell against Linux.
2. Compare pre-Linux and post-Linux `PORTSC` for `HS05`.
3. If routing differs, test an xHCI PCI quirk or pre-boot routing write.
4. If routing is identical, instrument xHCI reset/handoff and port power
   sequencing with dynamic debug.
5. Keep SPI as a separate diagnostic branch focused on PIO vs DMA, SPI
   clock/mode, and LPSS runtime PM.

## External References

- Upstream `applespi` patch discussion:
  <https://www.mail-archive.com/linux-kernel%40vger.kernel.org/msg1938305.html>
- LKDDb `CONFIG_KEYBOARD_APPLESPI` entry:
  <https://cateee.net/lkddb/web-lkddb/KEYBOARD_APPLESPI.html>
- CachyOS Limine keyboard/trackpad report:
  <https://github.com/CachyOS/distribution/issues/415>
- rEFInd shell script and pre-boot PCI example:
  <https://www.rodsbooks.com/refind/configfile.html>
- UEFI Shell `pci` command reference:
  <https://support.hpe.com/hpesc/public/docDisplay?docId=sd00002251en_us&docLocale=en_US&page=GUID-D7147C7F-2016-0901-0A6D-000000000A9B.html>
- UEFI Shell `mm` command discussion:
  <https://stackoverflow.com/questions/40885828/efi-shell-command-and-register-r-w>
