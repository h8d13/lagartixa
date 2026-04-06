#!/bin/bash
# SPDX-License-Identifier: 0BSD
# SPDX-FileCopyrightText: 2026 h8d13
# shellcheck disable=SC1091,SC1090

# Klartix - Artix Linux Bootstrap Installer

# Script for my good friend Klagan who values low ressource/data usage & minimalist approach -sysd

# Assumes x86_64, GPT/UEFI, and can run from any Linux distro
# Does not need an ISO bootstraps directly from official tool

##################################################################################################

#                                                                       :--=:
#                                  .                     .           ..--=====
#                           :      *+  .:                           .+-==++==+
#                                 .%*:==+.- .                      @#=****+===    .
#                          .       .--==.==. ---= .-.            :=-***%#++=:+   -=:.*-:
#                                  -====++-+. =--+-.          .---+*+*+*+*+@@....-:=+:
#                         .=..=-. .----=--#*+==--::--         :-==++******#@: .+---=---+%= ..  -
#                .          :**+==-===-+==#*+====-:.          ==+++*****+*+*- ..-===++=:
#                                .--==:       .+=-::         .=++**##*##**+#=:.-=+=++*+*+.
#                                 :--=.         -=--:  .    ..-++*****#####*-.:-=+-  .::..#.
#                           .:  . .--=-         :----:.    ..:-+++*+**####*=..-==+........
#                                 .--==.        .----------:--=+=+++*####*=:.===+=........
#                                 ::-=--        .--==-=-===+===+**+**=+*==----=+==.  .. ...
#                                 :--=--.       .+*#****+-==+=++*+***+===+=====++*..  ...
#             +                   :--*=-:.       :++++***#-===++*=****%******+++=..-... .
#                             :  .:--=::-         .:::::=:===+++++*****##*+==-.   ::...
#                                .------:    :        ..:-=#++++=#****#*-        ..-...
#                                :---=---         ...:-=-=*++++++*****+:         ......:...
#                                :--====-.   ...::-=-====+**++++#***+=.          ...  . ...      ..
#          =                    :---==++=..:--==-====++++**+**+*#*#*=:          .. ..      .
#                               ----=======+===+++*****+***++**%##*+:          ....
#                           .--=++++++***+++****+#*##***++=+#*###*+-.         .....
#                      .:::+==++*+*++*+***+*+++*****++++*#*###%#**-.           .   .
#                    .::---=++*****########*****##*##%###%#%%%##*@:               :.:        .     .
#                   :---=+=**##%%%#**###%%##*#####%#%%%%%%%%#*++:.
#                 .---+=+*#%%%%%@@%@%*+*%@%%%#%%%%%%%%%@%%#**+=.
#                :=-==+*######***###*###*+=#@@@%@@@@%%##***+=.                  .
#          .   .:--=++#*=#*+=...=.=*#******+=+###******++=-.
#              -=+=+*#+*=.         .+-=*++++*--*+++++==:..
#            .---=**++-              -:--+=+*==.
#            .-==+*=*         -   . .--==+**#*+.                                      .        .
#           .-==+**+               .-+**###*+=-                                                :
#           -=++**             ...:=**+*====-.                                      .           .
#        ..--=+**             =-+*+*=+=*=-:.::.        .                  .                   .
#         :-=+**             -=      -==-+-:  :                               .
#        :-=+**                      .-= .+%-                              :              .
#       .==+*+                       .++    =
#      .==+**                         =-
#     :=++++                           .
#   .:=+*=-                                             =
#   -=+*+.
# .=+++=      .                     https://github.com/h8d13/lagartixa
#:=+*+                                                                                   :
#=+++
#++.     ..                                           .
#

###################################################################################################

#       $$\                                          $$\     $$\
#       $$ |                                         $$ |    \__|
#       $$ | $$$$$$\   $$$$$$\   $$$$$$\   $$$$$$\ $$$$$$\   $$\ $$\   $$\ $$$$$$\
#       $$ | \____$$\ $$  __$$\  \____$$\ $$  __$$\\_$$  _|  $$ |\$$\ $$  |\____$$\
#       $$ | $$$$$$$ |$$ /  $$ | $$$$$$$ |$$ |  \__| $$ |    $$ | \$$$$  / $$$$$$$ |
#       $$ |$$  __$$ |$$ |  $$ |$$  __$$ |$$ |       $$ |$$\ $$ | $$  $$< $$  __$$ |
#       $$ |\$$$$$$$ |\$$$$$$$ |\$$$$$$$ |$$ |       \$$$$  |$$ |$$  /\$$\\$$$$$$$ |
#       \__| \_______| \____$$ | \_______|\__|        \____/ \__|\__/  \__|\_______|
#                   $$\   $$ |
#                   \$$$$$$  |
#                   \______/

# Roughly in Portuguese tranlates to "small lizard" - "lagarto" + "ixa". And "lacertus" from latin.
# This script is in charge of anything bootstrap tool didn't do for a stage 2.. not all tested yet.

###################################################################################################

# LOCATION
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# CONF FILE SRC REL TO THIS SCRIPT
CONF_FILE="${1:-${SCRIPT_DIR}/default.conf}" # fallback to default
[ ! -f "$CONF_FILE" ] && {
	echo "[ERROR] Config file not found: $CONF_FILE" >&2
	exit 1
}
. "$CONF_FILE"

# UTILS
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
RESET='\033[0m'

info() { printf "${GREEN}[INFO]${RESET}  %s\n" "$*"; }
warn() { printf "${YELLOW}[WARN]${RESET}  %s\n" "$*"; }
die() {
	printf "${RED}[ERROR]${RESET} %s\n" "$*" >&2
	exit 1
}
nlp() { echo; }
obanner() { printf "\n${BOLD}${GREEN}=== %s ===${RESET}\n" "$*"; }
cbanner() { printf "${BOLD}${GREEN}=== %s ===${RESET}\n" "$*"; }
reop() { printf "${BOLD}${GREEN}%s${RESET}\n" "$*"; }

# chroot wrapper match artix-bootstrap style
# ours has to be a bit more aggressive because
# we run processes such as grub-install

run_chroot() {
	local dest="$1"
	shift
	LC_ALL=C mount --types proc /proc "$dest/proc"
	LC_ALL=C mount --rbind /sys "$dest/sys"
	LC_ALL=C mount --make-rslave "$dest/sys"
	LC_ALL=C mount --rbind /dev "$dest/dev"
	LC_ALL=C mount --make-rslave "$dest/dev"
	LC_ALL=C chroot "$dest" "$@"
	local ret=$?
	# Kill only processes rooted inside the chroot, not host processes with open files there
	for pid in /proc/*/root; do
		[ "$(readlink "$pid")" = "$dest" ] || continue
		kill -9 "${pid%/root}" 2>/dev/null || true
	done
	sleep 1
	LC_ALL=C umount -R "$dest/proc" 2>/dev/null || LC_ALL=C umount -Rl "$dest/proc" 2>/dev/null || true
	LC_ALL=C umount -R "$dest/sys" 2>/dev/null || LC_ALL=C umount -Rl "$dest/sys" 2>/dev/null || true
	LC_ALL=C umount -R "$dest/dev" 2>/dev/null || LC_ALL=C umount -Rl "$dest/dev" 2>/dev/null || true
	return $ret
}

# automatic count minus the next 2 uses
TOTAL_STEPS=$(($(grep -c 'show_progress' "$0") - 2))
CURRENT_STEP=0
# Empty vars prompted below
TARGET_DISK=""
TARGET_USER=""
USER_PASSWORD=""
ROOT_PASSWORD=""

# HELPERS
show_progress() {
	local step_desc="$1"
	CURRENT_STEP=$((CURRENT_STEP + 1))
	local percent=$((CURRENT_STEP * 100 / TOTAL_STEPS))
	local bar_width=50
	local filled=$((CURRENT_STEP * bar_width / TOTAL_STEPS))
	local empty=$((bar_width - filled))
	local bar=""
	for _ in $(seq 1 "$filled"); do bar="${bar}█"; done
	for _ in $(seq 1 "$empty"); do bar="${bar}░"; done
	printf "\r\033[K"
	printf "${GREEN}[%s]${RESET} %3d%% (%d/%d)\n" "$bar" "$percent" "$CURRENT_STEP" "$TOTAL_STEPS"
	info "$step_desc"
}

# CLEANUP TRAP
cleanup() {
	local exit_code=$?
	[ -z "$TARGET_MOUNT" ] && return
	if [ $exit_code -ne 0 ]; then
		warn "Installation failed or interrupted cleaning up..."
	fi
	sync 2>/dev/null || true
	umount -R "$TARGET_MOUNT" 2>/dev/null || umount -Rl "$TARGET_MOUNT" 2>/dev/null || true
}
trap cleanup EXIT

# START

# PREFLIGHT
[ "$(id -u)" -ne 0 ] && die "This script must be run as root."

REQUIRED_BIN=(bash curl sed gawk tar gzip xz zstd parted)
missing=()
for cmd in "${REQUIRED_BIN[@]}"; do
	command -v "$cmd" &>/dev/null && echo "Checked: $cmd OK." || missing+=("$cmd")
done
[ ${#missing[@]} -gt 0 ] && die "Missing required dependencies: ${missing[*]}"

# PROMPTS
## Target > Auth > Print CFG > Confirm

obanner "Klartix - Artix Linux Bootstrap Installer"
nlp
info "Current block devices:"
lsblk
nlp
info "Example: /dev/sdx"
read -rp "Enter target disk: " TARGET_DISK
[ -z "$TARGET_DISK" ] && die "Target disk cannot be empty."
[ ! -b "$TARGET_DISK" ] && die "Device $TARGET_DISK does not exist or is not a block device."
nlp

info "Installation layout:"
cat default.conf
nlp
warn "WARNING: This will ERASE ALL DATA on $TARGET_DISK!"
nlp
cbanner "Klartix - Artix Linux Bootstrap Installer"
nlp
info "Target configuration:"
echo "  Hostname:     $TARGET_HOSTNAME"
echo "  Timezone:     $TARGET_TIMEZONE"
echo "  Console KB:   $VCONSOLE_KB"
nlp
read -rp "Begin installation? [y/N]: " confirm
[[ ! "$confirm" =~ ^[Yy]$ ]] && {
	warn "Installation cancelled."
	exit 0
}
nlp

# CREDS
if [ "$LOCK_ROOT" != "1" ]; then
	read -rsp "Enter root password: " ROOT_PASSWORD
	nlp
	read -rsp "Confirm root password: " ROOT_PASSWORD_CONFIRM
	nlp
	[ "$ROOT_PASSWORD" != "$ROOT_PASSWORD_CONFIRM" ] && die "Root passwords do not match."
	[ -z "$ROOT_PASSWORD" ] && die "Root password cannot be empty."
fi

read -rp "Enter a username: " TARGET_USER
[ -z "$TARGET_USER" ] && die "Username cannot be empty."
read -rsp "Enter user password: " USER_PASSWORD
nlp
read -rsp "Confirm user password: " USER_PASSWORD_CONFIRM
nlp
[ "$USER_PASSWORD" != "$USER_PASSWORD_CONFIRM" ] && die "User passwords do not match."
[ -z "$USER_PASSWORD" ] && die "User password cannot be empty."

# Target system package manager command (used in chroot)
PM_CMD="pacman -S --noconfirm --needed"

show_progress "Cleaning up previous installation attempts..."
umount -R "$TARGET_MOUNT" 2>/dev/null || true

# START
TARGET_MOUNT="/mnt/artix"
mkdir -p "$TARGET_MOUNT"

# DISKS
show_progress "Partitioning $TARGET_DISK..."
wipefs -af "$TARGET_DISK"
udevadm settle

parted -s -a optimal "$TARGET_DISK" -- mklabel gpt \
	mkpart EFI fat32 1MiB "$EFI_SIZE" \
	set 1 esp on \
	mkpart root "$TARGET_FS" "$EFI_SIZE" 100%

show_progress "Updating kernel partition table..."
partprobe "${TARGET_DISK}"
sleep 2

# PARTITIONS
# hack to add the p for nvme/sdd device vs usb
if [[ "$TARGET_DISK" == *"nvme"* ]] || [[ "$TARGET_DISK" == *"mmcblk"* ]] || [[ "$TARGET_DISK" == *"loop"* ]]; then
	PART_PREFIX="p"
else
	PART_PREFIX=""
fi

EFI_PART="${TARGET_DISK}${PART_PREFIX}1"
ROOT_PART="${TARGET_DISK}${PART_PREFIX}2"

show_progress "Wiping existing signatures..."
wipefs -af "$ROOT_PART" 2>/dev/null || true
partprobe "${TARGET_DISK}" 2>/dev/null || true
sleep 1

# FORMATTING
show_progress "Formatting filesystems..."
mkfs.fat -F32 "$EFI_PART"
case "$TARGET_FS" in
ext4) mkfs.ext4 -F "$ROOT_PART" ;;
btrfs) mkfs.btrfs -f "$ROOT_PART" ;;
xfs) mkfs.xfs -f "$ROOT_PART" ;;
f2fs) mkfs.f2fs -f "$ROOT_PART" ;;
esac

# MOUNT
show_progress "Mounting filesystems..."
mount "$ROOT_PART" "$TARGET_MOUNT"

mkdir -p "$TARGET_MOUNT/efi"
mount "$EFI_PART" "$TARGET_MOUNT/efi"

# BOOTSTRAP
BOOTSTRAP="$SCRIPT_DIR/bootstrap/artix-bootstrap.sh"
show_progress "Bootstrapping $TARGET_INI and $SEAT_MGR"
if [ -n "$MIRROR_URL" ]; then
	info "Using mirror: $MIRROR_URL"
	"$BOOTSTRAP" -r "$MIRROR_URL" -i "$TARGET_INI" -s "$SEAT_MGR" "$TARGET_MOUNT" \
		|| die "Bootstrap failed."
else
	info "Using auto mirrors"
	"$BOOTSTRAP" -i "$TARGET_INI" -s "$SEAT_MGR" "$TARGET_MOUNT" \
		|| die "Bootstrap failed."
fi

# FSTAB
show_progress "Generating fstab..."
ROOT_UUID=$(blkid -s UUID -o value "$ROOT_PART")
EFI_UUID=$(blkid -s UUID -o value "$EFI_PART")
cat >"$TARGET_MOUNT/etc/fstab" <<FSTAB
# <file system>                             <mount>  <type>       <options>        <dump> <pass>
UUID=$ROOT_UUID  /     $TARGET_FS   defaults         0      1
UUID=$EFI_UUID   /efi  vfat         defaults         0      2
/dev/zram0                                  none     swap         defaults,pri=100 0      0
FSTAB

# CHROOT CONFIG STAGE 2
show_progress "Creating chroot configuration script..."
cat >"$TARGET_MOUNT/configure.sh" <<EOF
#!/bin/bash
set -e

enable_svc() {
    case "$TARGET_INI" in
        openrc) rc-update add "\$1" default ;;
        runit)  ln -s "/etc/runit/sv/\$1" /etc/runit/runsvdir/default/ ;;
        s6)     s6-rc-bundle-update add default "\$1" ;;
        dinit)  dinitctl enable "\$1" ;;
    esac
}
# install_svc <pkg> [svcname]  — installs pkg + pkg-$TARGET_INI then enables the service
install_svc() {
    local pkg="\$1" svc="\${2:-\$1}"
    $PM_CMD "\$pkg" "\$pkg-$TARGET_INI"
    enable_svc "\$svc"
}

echo "Initializing pacman keyring..."
pacman-key --init
pacman-key --populate artix

echo "Updating package databases..."
pacman -Sy

# Timezone & clock
ln -sf /usr/share/zoneinfo/$TARGET_TIMEZONE /etc/localtime
hwclock --systohc

# Locale
echo "$TARGET_LOCALE UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=$TARGET_LOCALE" > /etc/locale.conf

# Console keymap & font vconsole.conf read by mkinitcpio regardless of init
printf "KEYMAP=%s\nFONT=%s\n" "$VCONSOLE_KB" "$VCONSOLE_FONT" > /etc/vconsole.conf
if [ "$TARGET_INI" = "openrc" ]; then
    printf 'keymap="%s"\nwindowkeys="YES"\nextended_keymaps=""\n' "$VCONSOLE_KB" > /etc/conf.d/keymaps
    echo "consolefont=\"$VCONSOLE_FONT\"" > /etc/conf.d/consolefont
fi

# Hostname
echo "$TARGET_HOSTNAME" > /etc/hostname
cat > /etc/hosts << HOSTS
127.0.0.1  localhost
::1        localhost
127.0.1.1  $TARGET_HOSTNAME.localdomain $TARGET_HOSTNAME
HOSTS

# DNS
printf "nameserver $DNS1\nnameserver $DNS2\n" > /etc/resolv.conf

# Root password
[ "$LOCK_ROOT" != "1" ] && echo "root:$ROOT_PASSWORD" | chpasswd

# Kernel, bootloader & base packages
echo "Installing kernel and base packages..."
$PM_CMD \
	$HW_CPU \
    $KERNEL \
    $FW \
    grub mkinitcpio \
    $ELEV \
    $EDITOR

[ "$_KHEADERS" = "1" ] && $PM_CMD "${KERNEL}-headers"
[ -n "$HW_GPU" ]   && $PM_CMD $HW_GPU
[ -n "$HW_SOUND" ] && $PM_CMD $HW_SOUND

# Users/Perms
_GROUPS="wheel"
if [ "$SEAT_MGR" != "elogind" ]; then
    groupadd -f seat
    _GROUPS="wheel,seat"
fi
useradd -m -s /bin/bash -G "\$_GROUPS" "$TARGET_USER"
echo "$TARGET_USER:$USER_PASSWORD" | chpasswd

# Privilege esc
case "$ELEV" in
    sudo) sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers ;;
    doas)
        printf 'permit persist %s as root\n' "$TARGET_USER" > /etc/doas.conf
        chown root:root /etc/doas.conf
        chmod 0644 /etc/doas.conf
        ;;
esac

# Seat management (seatd-openrc already installed by bootstrap to pin init-logind provider)
if [ "$SEAT_MGR" = "elogind" ]; then
    install_svc elogind
else
    install_svc seatd
    # elogind handles XDG_RUNTIME_DIR automatically seatd does not
    mkdir -p /etc/local.d
    cat > /etc/local.d/xdg-runtime.start << LOCALD
#!/bin/sh
uid=\$(id -u $TARGET_USER)
mkdir -p /run/user/\$uid
chown $TARGET_USER:$TARGET_USER /run/user/\$uid
chmod 0700 /run/user/\$uid
LOCALD
    chmod +x /etc/local.d/xdg-runtime.start
    cat > /etc/profile.d/xdg-runtime-dir.sh << 'XDG'
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
XDG
fi

# Network setup
case "$NETWORK" in
    nm|nm-iwd)
        install_svc networkmanager NetworkManager
        if [ "$NETWORK" = "nm-iwd" ]; then
            $PM_CMD iwd
            mkdir -p /etc/NetworkManager/conf.d
            printf '[device]\nwifi.backend=iwd\n' > /etc/NetworkManager/conf.d/wifi-backend.conf
        fi
        ;;
    iwd-dhcpc)
        # iwd handles WiFi only, dhcpcd covers ethernet
        install_svc iwd
        install_svc dhcpcd
        ;;
    dhcpc)
        # dhcpcd covers ethernet only
        install_svc dhcpcd
        ;;
esac

# zram swap
mkdir -p /etc/udev/rules.d
cat > /etc/udev/rules.d/99-zram.rules << ZRAM
ACTION=="add", KERNEL=="zram0", ATTR{comp_algorithm}="$ZRAM_ALGO", ATTR{disksize}="$ZRAM_SIZE", RUN="/usr/bin/mkswap -U clear /dev/%k"
ZRAM

mkdir -p /etc/modules-load.d
echo 'zram' > /etc/modules-load.d/zram.conf

mkdir -p /etc/sysctl.d
cat > /etc/sysctl.d/99-lagar.conf << SYSCTL
kernel.kptr_restrict = 2
kernel.yama.ptrace_scope = 1
kernel.sched_autogroup_enabled = 0
vm.swappiness = $VM_SWAPPINESS
vm.watermark_boost_factor = $VM_WATERMARK_BOOST
vm.watermark_scale_factor = $VM_WATERMARK_SCALE

vm.page-cluster = 0
vm.vfs_cache_pressure = 50
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5

net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mtu_probing = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv6.conf.all.use_tempaddr = 2
net.ipv6.conf.default.use_tempaddr = 2
SYSCTL

[ "$PPD" = "1" ] && install_svc power-profiles-daemon

$PM_CMD $EXTRAS

# mkinitcpio busybox type hooks
sed -i 's/^HOOKS=.*/$TARGET_HOOKS/' /etc/mkinitcpio.conf
mkinitcpio -P

# GRUB
grub-install --target=x86_64-efi --efi-directory=/efi --boot-directory=/efi --removable
grub-mkconfig -o /efi/grub/grub.cfg

# Lock root if configured
if [ "$LOCK_ROOT" = "1" ]; then
    passwd -l root
    echo "Root account locked. Use $ELEV from $TARGET_USER."
fi
EOF
show_progress "Making configuration script executable..."
chmod +x "$TARGET_MOUNT/configure.sh"

# RUN
show_progress "Executing system configuration in chroot..."
run_chroot "$TARGET_MOUNT" /bin/bash /configure.sh

if [ "${GRIMAUR:-0}" = "1" ]; then
	show_progress "Deploying grimaur..."
	run_chroot "$TARGET_MOUNT" $PM_CMD base-devel git python
	install -m 755 "$SCRIPT_DIR/src/lixa/grimaur" "$TARGET_MOUNT/usr/local/bin/grimaur"
	[ "$ELEV" = "doas" ] && run_chroot "$TARGET_MOUNT" \
		sed -i 's/^#\?PACMAN_AUTH=.*/PACMAN_AUTH=(doas)/' /etc/makepkg.conf
fi

show_progress "Cleaning up configuration script..."
rm "$TARGET_MOUNT/configure.sh"

INSTALL_OK=1

show_progress "Syncing and unmounting..."
sync
umount -R "$TARGET_MOUNT" 2>/dev/null || umount -Rl "$TARGET_MOUNT" 2>/dev/null || true

# sanity check
mount | grep "artix"

nlp
if [ "${INSTALL_OK:-0}" -eq 1 ]; then
	reop "=== Klartix installation complete! ==="
	reop "You can now reboot into your new Artix Linux system."
	info "Init:  $TARGET_INI"
	info "User:  $TARGET_USER"
else
	warn "Installation finished with errors. Review the output above and report https://github.com/h8d13/lagartixa."
fi
