# Lagartixa

Dev rules: 

Bash only - only use libs available in the `base` ISO or small libs/deps, all stated in the source code.

`bash coreutils curl sed gawk tar gzip xz zstd parted`

No ISO needed -> bootstrap - Target: `x86_64` UEFI.

---

Filesystem tools (based on `TARGET_FS`):

| Filesystem | Tool |
|------------|------|
| `ext4` | - |
| `btrfs` | `btrfs-progs` |
| `xfs` | `xfsprogs` |
| `f2fs` | `f2fs-tools` |

Intentionally simple `EFI + /`: One config [file](./default.conf), EVERYTHING must be variables that can be matched to options, one script.

Goal was to show the minimal working PoC and to let the rest be user, hacked on. 

[`Lagartixa`](./klartix.sh) is a single-script, config-driven stage 2 installer for [Artix Linux](https://artixlinux.org/). And limits it's scope to this.

It wraps (and modifies) [`artix-bootstrap`](https://gitea.artixlinux.org/artix/artix-bootstrap/) official tool and drives the system to a bootable, login-ready state partitioning, filesystem, locale, users, seat manager, networking, hardware-drivers, bootloader, services and init system freedom.

This doesn't include Desktops/Window Managers, or any post initial configs (stage 3). On purpose.

## Setup / Testing: 

> Edit the [`default.conf`](./default.conf)

```shell
sudo ./test-image.sh        # default creates /dev/loop0 
rm /tmp/artix-test.img      # reset output img
# flash or test in qemu/vmware see test-qemu.sh
# bare-metal pick disk direcly
sudo dd if=/tmp/artix-test.img of=/dev/sdX bs=4M status=progress conv=fsync
# can also be used on a disk target directly
sudo bash klartix.sh
```

> Careful `dd` and might look frozen but is not, is flushing (depending on how slow is your disk/pc).

---

## Ressources: 

Findings that were made during this project: See [here](.github/finds.md)

MIRRORS: https://status.artixlinux.org/mirrors/status/

> Archived mirrors, to upgrade fully refresh after editing `/etc/pacman.d/mirrorlist` then `pacman -Syyu`

I have also included some tools I've used in `src/`

WIKIS: 
https://wiki.artixlinux.org/ 
https://wiki.gentoo.org/wiki/Main_Page
https://gitea.artixlinux.org/artix/artix-bootstrap/

