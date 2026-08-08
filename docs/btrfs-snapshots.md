# btrfs snapshots & restore (rollback safety net)

Root-level state that git does not cover — untracked `/etc` (fstab, mkinitcpio,
grub, pacman.conf, LUKS UUIDs), pacman package *versions* (the package list in
`system-packages.nix` is unpinned), and untracked home data — is protected by
btrfs snapshots instead of a version-control tool.

## The big picture

The root filesystem is a btrfs subvolume called `@` (mounted at `/`), and home
is a sibling subvolume `@home` (mounted at `/home`). Snapshots are COW copies:
they are near-instant and cost almost no disk until the original changes, and
an entire system state can be captured by snapshotting one subvolume.

A "rollback" is two separate events, deliberately split:

1. **Boot into a snapshot** — pick it in the GRUB `Snapshots` submenu. The
   kernel and initramfs come from the shared `/boot` (a separate vfat
   partition), only the root subvolume is swapped, so the snapshot must boot
   on its own.
2. **Promote it** — once the snapshot is verified good, `restore.sh` swaps it
   in under the `@` name so it becomes the default boot.

You never *need* to do step 2 to inspect a snapshot, and you never promote a
snapshot you haven't booted into. The safe order is: snapshot → boot into it →
verify → restore.sh → reboot.

## Files involved

| File                    | Tracked? | Role                                                            |
| ----------------------- | -------- | --------------------------------------------------------------- |
| `build/snapshot.sh`     | yes      | creates snapshots, refreshes GRUB, prunes old ones              |
| `build/restore.sh`      | yes      | promotes a booted snapshot to be the new default root           |
| `config/grub.d/40-snapshots` | yes | GRUB menu script; emits the `Snapshots` submenu                 |
| `build/system-config.sh`| yes      | deploys `config/grub.d/` → `/etc/grub.d/`, regenerates grub.cfg |

`/.snapshots` is a dedicated btrfs subvolume that holds all snapshots. It is
deliberately *not* a sub-subvolume of `@`, so it is not re-snapshotted with
every run.

## 1. `build/snapshot.sh` — take the snapshot

```sh
build/snapshot.sh                      # snapshot @, keep last 5
build/snapshot.sh --home               # also snapshot @home
build/snapshot.sh --keep 10            # prune to keep 10 root snapshots
build/snapshot.sh --label before-rice  # readable name suffix
```

Run this *before* a risky change (kernel update, config rewrite, pacman -Syu).
It self-sudoes if needed, so run it as your user.

Steps it performs:

- **Sanitize the label** into a filename-safe slug and build the name:
  `<YYYYMMDD-HHMMSS>` plus `-<label>` when given (e.g. `20260807-183000-before-rice`).
- **Snapshot root**: `btrfs subvolume snapshot / /.snapshots/<name>`. The
  snapshot is created **read-write on purpose** — read-only snapshots can fail
  to boot because services need a writable root.
- **Snapshot home (with `--home`)**: `@home` → `/.snapshots/<name>-home`. The
  `-home` suffix is how the other scripts recognise a home snapshot.
- **Refresh GRUB**: runs `grub-mkconfig` so the new snapshot gets a boot entry.
- **Prune** to `--keep` (default 5): lists the root snapshots newest-first by
  mtime and deletes everything past the keep count, deleting the matching
  `-home` snapshot alongside. It only counts root snapshots (`-home` names are
  skipped from the count), then refreshes GRUB again if anything was deleted so
  the menu no longer references removed snapshots.

## 2. `config/grub.d/40-snapshots` — how a snapshot boots

This is a `/etc/grub.d/` script, executed by `grub-mkconfig`. It is deployed by
`build/system-config.sh` and only takes effect after a snapshot exists. It
emits a `Snapshots` submenu with one `menuentry` per root snapshot.

Key mechanics:

- It **copies the boot lines out of the existing `grub.cfg`** (`search`,
  `linux`, `initrd`, and all `insmod` lines). Because those are copied from the
  config the machine actually boots with, LUKS UUIDs, `rootflags`, and
  kernel/initrd paths always match. The **only** rewrite is
  `subvol=@` → `subvol=@snapshots/<name>` on the linux line.
- It **skips `-home` snapshots** — a home snapshot has no bootloader, it is
  not a bootable root.
- `/boot` is a separate vfat partition, so kernel and initramfs are **shared**
  across every entry; only the root subvolume differs per snapshot.
- It bails out cleanly if `/.snapshots` or `grub.cfg` are missing, or there are
  no root snapshots.

So "booting into a snapshot" = booting the same kernel, with the same
initramfs, but with the root subvolume pointed at a frozen copy of `@` from the
past. Because the snapshot is writable, the box runs normally while you verify
it — that is exactly what lets you test before committing.

## 3. `build/restore.sh` — promote a snapshot to default

```sh
build/restore.sh list               # show snapshots + which is currently booted
build/restore.sh <name>             # promote snapshot <name> to root @
build/restore.sh <name> --home      # also promote the matching <name>-home
```

`restore.sh` cannot swap the live root `@` while it is mounted as `/`, which is
why it **must be run from inside the booted snapshot**. It self-sudoes, then:

- **`list` mode**: prints every snapshot in `/.snapshots` and marks the one the
  box is currently booted from. It reads the booted subvolume from the kernel's
  mount options via `findmnt` (`subvol=@snapshots/<name>`).
- **Safety checks**: refuses to run unless the box is booted from a snapshot
  (i.e. `findmnt` reports a `@snapshots/` subvol, not plain `@`), and refuses a
  name mismatch — you must be booted into exactly the snapshot you name.
- **Mount the top level**: mounts `subvolid=5` (the btrfs top-level, which
  contains `@`, `@home`, `@snapshots`) at `/mnt/snap-restore`, so it can rename
  subvolumes underneath the live ones. It unmounts it again on exit via a
  `trap`, so a failure never leaves it half-mounted.
- **Keep the current root**: renames `@` → `@.old-<stamp>`. This is the safety
  net and is **never auto-deleted**.
- **Promote**: `btrfs subvolume snapshot @snapshots/<name> → @` — a new
  writable subvolume under the `@` name whose contents are the verified
  snapshot.
- **`--home`**: `@home` is still mounted (unlike `@`, which was replaced by
  booting the snapshot), so it first unmounts `/home`, renames `@home` →
  `@home.old-<stamp>`, snapshots `<name>-home` → `@home`, and remounts. If the
  matching `-home` snapshot is missing it leaves `@home` alone and says so.
- Prints the exact command to delete the `@.old-*` safety net once you are
  happy — but never runs it for you.

## 4. `build/system-config.sh` — the deployment glue

`/etc/grub.d/40-snapshots` is repo-tracked, but `/etc` is root-owned and
outside home-manager's scope. `system-config.sh` copies every file in
`config/grub.d/` to `/etc/grub.d/`, and reruns `grub-mkconfig` when any of them
change — so the snapshot boot entries only appear after this script has run
once.

## The full rollback sequence

1. **Before the risky change**: `build/snapshot.sh --label <what-you-are-about-to-do>`.
2. Reboot → GRUB `Snapshots` submenu → pick the snapshot.
3. **Verify** the snapshot boots and works (this is the whole point — you test
   before you commit).
4. From that booted snapshot: `build/restore.sh <name> [--home]` — promotes it
   to the default root, keeping the old `@` as `@.old-<stamp>`.
5. Reboot. The restored system now starts by default.
6. Old roots stay under `@.old-*` / `@home.old-*` until you delete them with
   the printed command. Never skip the safety net delete prompt — the old root
   is the one thing that still boots the pre-change state.

## What snapshots do NOT cover

- The snapshot itself lives inside `/.snapshots` on the same device — it does
  not survive a disk failure, only a software mistake.
- `/boot` is a separate vfat partition and is not snapshotted at all.
- `restore.sh` must be run **from** the snapshot — there is no way to roll back
  the live root subvolume directly.
