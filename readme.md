# artixinstall

Dev rules: 

Bash only - only use libs available in the `base` ISO or small libs/deps, all stated in the main script.
No ISO needed -> bootstrap
Target: `x86_64` UEFI.

One config file, EVERYTHING must be variables that can be matched to options, one script.

## Run

```shell
sudo ./test-image.sh        # default 
sudo losetup -d /dev/loop0  # detach loop device
rm /tmp/artix-test.img      # reset img
# flash or qemu
sudo dd if=/tmp/artix-test.img of=/dev/sdX bs=4M status=progress conv=fsync
# resize/create new parts as needed
```

> Careful that `dd` might look frozen but is not, is flushing (depending on how slow is your disk/pc).

---

Ressources: 


AIS: https://github.com/archlinux/arch-install-scripts

WIKIS: 
https://wiki.artixlinux.org/ 
https://wiki.gentoo.org/wiki/Main_Page
https://gitea.artixlinux.org/artix/artix-bootstrap/

Not used:

TUI: https://man7.org/linux/man-pages/man1/tput.1.html