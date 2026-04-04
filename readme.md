# Lagartixa

Dev rules: 

Bash only - only use libs available in the `base` ISO or small libs/deps, all stated in the main script.
No ISO needed -> bootstrap
Target: `x86_64` UEFI.

One config file, EVERYTHING must be variables that can be matched to options, one script.
Goal is to show the minimal working PoC and to let the rest be user defined through conf. 

Testing: I mostly test from host straight, create the in a loop device, then copy `.img` output to a shitty USB.
Reproducible through mirror choice, this means a build one day is the same the next.

## Run

```shell
sudo ./test-image.sh        # default 
rm /tmp/artix-test.img      # reset img
# flash or qemu/vmware
sudo dd if=/tmp/artix-test.img of=/dev/sdX bs=4M status=progress conv=fsync
# resize/create new parts as needed
```

> Careful `dd` might look frozen but is not, is flushing (depending on how slow is your disk/pc).

---

Ressources: 

AIS: https://github.com/archlinux/arch-install-scripts

WIKIS: 
https://wiki.artixlinux.org/ 
https://wiki.gentoo.org/wiki/Main_Page
https://gitea.artixlinux.org/artix/artix-bootstrap/

Not used:
TUI: https://man7.org/linux/man-pages/man1/tput.1.html
