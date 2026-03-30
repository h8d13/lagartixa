# artixinstall

Dev rules: 

Bash only - only use libs available in the `base` ISO or small libs. 
No ISO needed -> bootstrap
Target: `x86_64` UEFI.

One config file, EVERYTHING must be variables that can be matched to options, one script.

## Run

sudo ./test-image.sh        # default 
rm /tmp/artix-test.img

Flash it or test it in qemu directly.

---

Ressources: 

TUI: https://man7.org/linux/man-pages/man1/tput.1.html
AIS: https://github.com/archlinux/arch-install-scripts
WIKIS: 
https://wiki.artixlinux.org/ 
https://wiki.archlinux.org/title/Main_page 
https://wiki.gentoo.org/wiki/Main_Page
