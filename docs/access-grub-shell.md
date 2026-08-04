# Accessing the GRUB Shell and Bypassing rEFInd

To run the `setpci` commands before Linux boots, you need to access the GRUB shell. Currently, your system boots into rEFInd first (Boot0001), which then hands off to GRUB. You can change the EFI boot order to boot directly into GRUB (Boot0000) instead.

## 1. Change the Boot Order to Prioritize GRUB

Run this command from within your Arch Linux installation:

```bash
sudo efibootmgr -o 0000,0001,0080
```

### Explanation of the command:
- `sudo`: Runs the command as the root user, which is required to modify EFI variables.
- `efibootmgr`: The utility used to manage the UEFI boot manager settings.
- `-o 0000,0001,0080`: Sets the exact boot order. Based on your current EFI entries, `0000` is `grub_uefi`, `0001` is `rEFInd Boot Manager`, and `0080` is `Mac OS X`. Putting `0000` first ensures the system skips rEFInd and launches GRUB directly.

## 2. Rebuild the GRUB Configuration (Optional but recommended)

Your `/etc/default/grub` is already set up to show a menu (`GRUB_TIMEOUT_STYLE=menu` and `GRUB_TIMEOUT=5`), but it's good practice to ensure the generated config is up to date:

```bash
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

### Explanation of the command:
- `grub-mkconfig`: Reads the settings from `/etc/default/grub` and automatically generates a GRUB configuration script.
- `-o /boot/grub/grub.cfg`: Writes the generated configuration to the standard output path where GRUB expects to find it.

## 3. Accessing the GRUB Shell

1. Reboot the MacBook.
2. The system should now bypass rEFInd and go straight to the GRUB boot menu, which will display for 5 seconds.
3. When the GRUB menu appears, **do not press Enter**. Instead, press the **`c`** key on your keyboard.
4. This will drop you into the GRUB command line (the GRUB shell), which looks like `grub>`.

## 4. Running the Diagnostics

Once inside the GRUB shell, you can execute the commands mentioned in the diagnostics document to inspect the PCI state before Linux loads:

```text
insmod lspci
lspci
insmod setpci
setpci -s 00:14.0 d0.l
setpci -s 00:14.0 d4.l
setpci -s 00:14.0 d8.l
setpci -s 00:14.0 dc.l
```

## 5. Reverting Back to rEFInd

After you have collected the outputs you need, you can type `reboot` in the GRUB shell, or press `ESC` to return to the menu and boot into Linux. 

If you want to restore rEFInd as your default boot manager later, open a terminal in Linux and run:

```bash
sudo efibootmgr -o 0001,0000,0080
```
