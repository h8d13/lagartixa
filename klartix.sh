#!/bin/bash
# SPDX-License-Identifier: 0BSD
# SPDX-FileCopyrightText: 2026 h8d13
# shellcheck disable=SC1091

# Klartix - Artix Linux Bootstrap Installer
# Script for my good friend Klagan who values not being on Systemd & Minimalism approach
# Assumes x86_64, GPT/UEFI, and can run from any Linux distro
# Does not need an ISO bootstraps directly from official tool

# LOCATIONS
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# CONF FILE SRC 
. "${SCRIPT_DIR}/default.conf"

# UTILS
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { printf "${GREEN}[INFO]${RESET}  %s\n" "$*"; }
warn()    { printf "${YELLOW}[WARN]${RESET}  %s\n" "$*"; }
die()     { printf "${RED}[ERROR]${RESET} %s\n" "$*" >&2; exit 1; }
nlp()     { echo; }
obanner() { printf "\n${BOLD}${GREEN}=== %s ===${RESET}\n" "$*"; }
cbanner() { printf "${BOLD}${GREEN}=== %s ===${RESET}\n" "$*"; }
reop()    { printf "${BOLD}${GREEN}%s${RESET}\n" "$*"; }

# automatic count minus the next 2 uses
TOTAL_STEPS=$(( $(grep -c 'show_progress' "$0") - 2 ))
CURRENT_STEP=0

show_progress() {
    local step_desc="$1"
    CURRENT_STEP=$((CURRENT_STEP + 1))
    local percent=$((CURRENT_STEP * 100 / TOTAL_STEPS))
    local bar_width=50
    local filled=$((CURRENT_STEP * bar_width / TOTAL_STEPS))
    local empty=$((bar_width - filled))
    local bar=""
    for _ in $(seq 1 "$filled"); do bar="${bar}█"; done
    for _ in $(seq 1 "$empty");  do bar="${bar}░"; done
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

# Empty vars prompted below
TARGET_DISK=""
TARGET_USER=""
USER_PASSWORD=""
ROOT_PASSWORD=""

# Host prerequisites
PKGS="wget parted arch-install-scripts"
case "$TARGET_FS" in
    btrfs) PKGS="$PKGS btrfs-progs" ;;
    xfs)   PKGS="$PKGS xfsprogs" ;;
    f2fs)  PKGS="$PKGS f2fs-tools" ;;
esac

# PREFLIGHT
[ "$(id -u)" -ne 0 ] && die "This script must be run as root."

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
read -rp "Continue with this disk? [y/N]: " confirm
[[ ! "$confirm" =~ ^[Yy]$ ]] && { warn "Installation cancelled."; exit 0; }
nlp

cbanner "Klartix - Artix Linux Bootstrap Installer"
nlp
info "Target configuration:"
echo "  Hostname:     $TARGET_HOSTNAME"
echo "  Timezone:     $TARGET_TIMEZONE"
echo "  Console KB:   $VCONSOLE_KB"
nlp
read -rp "Begin installation? [y/N]: " confirm
[[ ! "$confirm" =~ ^[Yy]$ ]] && { warn "Installation cancelled."; exit 0; }
nlp

# CREDS
read -rsp "Enter root password: " ROOT_PASSWORD; nlp
read -rsp "Confirm root password: " ROOT_PASSWORD_CONFIRM; nlp
[ "$ROOT_PASSWORD" != "$ROOT_PASSWORD_CONFIRM" ] && die "Root passwords do not match."
[ -z "$ROOT_PASSWORD" ] && die "Root password cannot be empty."

read -rp "Enter a username: " TARGET_USER
[ -z "$TARGET_USER" ] && die "Username cannot be empty."
read -rsp "Enter user password: " USER_PASSWORD; nlp
read -rsp "Confirm user password: " USER_PASSWORD_CONFIRM; nlp
[ "$USER_PASSWORD" != "$USER_PASSWORD_CONFIRM" ] && die "User passwords do not match."
[ -z "$USER_PASSWORD" ] && die "User password cannot be empty."

# HOST SIDE
show_progress "Installing required packages on host..."
PM_CMD="pacman -S --noconfirm --needed"
# shellcheck disable=SC2086
$PM_CMD $PKGS
# to adapt if using a different PM

show_progress "Cleaning up previous installation attempts..."
umount -R "$TARGET_MOUNT" 2>/dev/null || true

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
    ext4)  mkfs.ext4  -F -E lazy_itable_init=1,lazy_journal_init=1 "$ROOT_PART" ;;
    btrfs) mkfs.btrfs -f "$ROOT_PART" ;;
    xfs)   mkfs.xfs   -f "$ROOT_PART" ;;
    f2fs)  mkfs.f2fs  -f "$ROOT_PART" ;;
esac

# MOUNT
show_progress "Mounting filesystems..."
mount "$ROOT_PART" "$TARGET_MOUNT"

mkdir -p "$TARGET_MOUNT/efi"
mount "$EFI_PART" "$TARGET_MOUNT/efi"

# BOOTSTRAP
BOOTSTRAP="$SCRIPT_DIR/artix-bootstrap/artix-bootstrap.sh"
show_progress "Bootstrapping Artix Linux with $TARGET_INI..."
if [ -n "$MIRROR_URL" ]; then
    info "Using mirror: $MIRROR_URL"
    "$BOOTSTRAP" -r "$MIRROR_URL" -i "$TARGET_INI" -s "$SEAT_MGR" "$TARGET_MOUNT"
else
    "$BOOTSTRAP" -i "$TARGET_INI" -s "$SEAT_MGR" "$TARGET_MOUNT"
fi

# FSTAB
show_progress "Generating fstab..."
ROOT_UUID=$(blkid -s UUID -o value "$ROOT_PART")
EFI_UUID=$(blkid -s UUID -o value "$EFI_PART")
cat > "$TARGET_MOUNT/etc/fstab" << FSTAB
# <file system>                             <mount>  <type>       <options>        <dump> <pass>
UUID=$ROOT_UUID  /     $TARGET_FS   defaults         0      1
UUID=$EFI_UUID   /efi  vfat         defaults         0      2
/dev/zram0                                  none     swap         defaults,pri=100 0      0
FSTAB

# CHROOT CONFIG

show_progress "Creating chroot configuration script..."
cat > "$TARGET_MOUNT/configure.sh" << EOF
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
$PM_CMD artix-keyring
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
echo "root:$ROOT_PASSWORD" | chpasswd

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
    rc-update add local default
    cat > /etc/profile.d/xdg-runtime-dir.sh << 'XDG'
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
XDG
fi

# Kernel, bootloader & base packages
echo "Installing kernel and base packages..."
$PM_CMD \
    $KERNEL $FW \
    grub mkinitcpio \
    $ELEV \
    git \
    $EDITOR

[ "$_KHEADERS" = "1" ] && $PM_CMD "${KERNEL}-headers"

# Users/Perms
_GROUPS="wheel"
if [ "$SEAT_MGR" != "elogind" ]; then
    groupadd -f seat
    _GROUPS="wheel,seat"
fi
useradd -m -s /bin/bash -G "$_GROUPS" "$TARGET_USER"
[ "$SEAT_MGR" != "elogind" ] && usermod -aG seat "$TARGET_USER"
echo "$TARGET_USER:$USER_PASSWORD" | chpasswd
case "$ELEV" in
    sudo) sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers ;;
    doas)
        printf 'permit persist %s as root\n' "$TARGET_USER" > /etc/doas.conf
        chown root:root /etc/doas.conf
        chmod 0644 /etc/doas.conf
        ;;
esac

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
cat > /etc/sysctl.d/99-custom-parameters.conf << SYSCTL
vm.swappiness = $VM_SWAPPINESS
vm.watermark_boost_factor = $VM_WATERMARK_BOOST
vm.watermark_scale_factor = $VM_WATERMARK_SCALE
SYSCTL

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
arch-chroot "$TARGET_MOUNT" /bin/bash /configure.sh

show_progress "Cleaning up configuration script..."
rm "$TARGET_MOUNT/configure.sh"

show_progress "Syncing and unmounting..."
sync

nlp
reop "=== Klartix installation complete! ==="
reop "You can now reboot into your new Artix Linux system."
info "Init:  $TARGET_INI"
info "User:  $TARGET_USER"
