# Lagartixa

Dev rules: 

Bash only - only use libs available in the `base` ISO or small libs/deps, all stated in the source code.

`bash coreutils curl sed gawk tar gzip xz zstd parted`

Filesystem tools (based on `TARGET_FS`):

| Filesystem | Tool |
|------------|------|
| `ext4` | - |
| `btrfs` | `btrfs-progs` |
| `xfs` | `xfsprogs` |
| `f2fs` | `f2fs-tools` |

No ISO needed -> bootstrap - Target: `x86_64` UEFI.

One config [file](./default.conf), EVERYTHING must be variables that can be matched to options, one script.

Goal is to show the minimal working PoC and to let the rest be user, hacked on. 

Testing: 

> Edit the `default.conf`

```shell
sudo ./test-image.sh        # default creates /dev/loop0 
rm /tmp/artix-test.img      # reset output img
# flash or test in qemu/vmware
sudo dd if=/tmp/artix-test.img of=/dev/sdX bs=4M status=progress conv=fsync
# bare-metal pick disk direcly
sudo bash klartix.sh
```

> Careful `dd` and might look frozen but is not, is flushing (depending on how slow is your disk/pc).

`Lagartixa` is a single-script, config-driven stage 2 installer for Artix Linux. And limits it's scope to this.

It wraps (and modifies) `artix-bootstrap` official tool (stage 1) and drives the system to a bootable, login-ready state partitioning, filesystem, locale, users,seat manager, networking, hardware-drivers, bootloader, services and init system freedom.

This doesn't include Desktops/Window Managers, or any post initial configs (stage 3). On purpose.

---

Ressources: 

MIRRORS: https://status.artixlinux.org/mirrors/status/

> Archived mirrors, to upgrade fully refresh after editing `/etc/pacman.d/mirrorlist` then `pacman -Syyu`

WIKIS: 
https://wiki.artixlinux.org/ 
https://wiki.gentoo.org/wiki/Main_Page
https://gitea.artixlinux.org/artix/artix-bootstrap/

