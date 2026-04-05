# Lagartixa

[`Lagartixa`](./klartix.sh) is a single-script, config-driven stage 1+2 installer for [Artix Linux](https://artixlinux.org/).

Wraps [`artix-bootstrap`](https://gitea.artixlinux.org/artix/artix-bootstrap/) (stage 1) and drives the system to a bootable, login-ready state: partitioning, filesystem, locale, users, seat manager, networking, hardware drivers, bootloader, services, and init system from any running Linux host. No ISO needed.

DE/WMs, and post-install config (stage 3) are out of scope. On purpose.

Target: `x86_64` UEFI. One [config file](./default.conf). Everything is a variable. Minimal PoC made to hack on.

---

## Dependencies

Bash only - libs available in `base` or explicitly listed below:

`bash coreutils curl sed gawk tar gzip xz zstd parted`

Filesystem tools (resolved from `TARGET_FS`):

| Filesystem | Tool |
|------------|------|
| `ext4` | - |
| `btrfs` | `btrfs-progs` |
| `xfs` | `xfsprogs` |
| `f2fs` | `f2fs-tools` |

---

## Setup / Testing

Edit [`default.conf`](./default.conf), then:

```shell
sudo ./test-image.sh        # creates /tmp/artix-test.img mounted at /dev/loop0
rm /tmp/artix-test.img      # reset output img

# flash or test in qemu/vmware
sudo dd if=/tmp/artix-test.img of=/dev/sdX bs=4M status=progress conv=fsync
./test-qemu.sh

# bare-metal pick disk at prompt
sudo bash klartix.sh
```

---

## Resources

- Mirrors: https://status.artixlinux.org/mirrors/status/
- Artix Wiki: https://wiki.artixlinux.org/
- Gentoo Wiki: https://wiki.gentoo.org/wiki/Main_Page
- artix-bootstrap: https://gitea.artixlinux.org/artix/artix-bootstrap/

> Mirrors are archived snapshots. After install, update `/etc/pacman.d/mirrorlist` then run `pacman -Syyu`.

Additional tools used during development are in `src/`. Findings made during this project: [finds.md](.github/finds.md)

