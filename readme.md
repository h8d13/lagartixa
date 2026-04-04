# Lagartixa

Dev rules: 

Bash only - only use libs available in the `base` ISO or small libs/deps, all stated in the source code.

`bash coreutils wget sed gawk tar gzip chroot xz zstd arch-install-scripts parted`

No ISO needed -> bootstrap - Target: `x86_64` UEFI.

One config file, EVERYTHING must be variables that can be matched to options, one script.

Goal is to show the minimal working PoC and to let the rest be user defined through conf. 

Testing: I mostly test from host straight, create a loop device, then copy `.img` output to a shitty USB.
Reproducible through mirror choice, this means a build one day is the same the next.

## Run

```shell
sudo ./test-image.sh        # default creates /dev/loop0 
rm /tmp/artix-test.img      # reset output img
# flash or test in qemu/vmware
sudo dd if=/tmp/artix-test.img of=/dev/sdX bs=4M status=progress conv=fsync
# bare-metal pick disk direcly
sudo bash klartix.sh
```

> Careful `dd` and might look frozen but is not, is flushing (depending on how slow is your disk/pc).

This project aims to build a stage 1 and limit it's scope to this. This doesn't include Desktops/Window Managers, or any post initial configs.

---

Ressources: 

Tools: https://github.com/archlinux/arch-install-scripts
https://github.com/archlinux/pacman-contrib

MIRRORS: https://status.artixlinux.org/mirrors/status/

> If you used mirrors to upgrade fully refresh after editing `/etc/pacman.d/mirrorlist` then `pacman -Syyu`

WIKIS: 
https://wiki.artixlinux.org/ 
https://wiki.gentoo.org/wiki/Main_Page
https://gitea.artixlinux.org/artix/artix-bootstrap/

