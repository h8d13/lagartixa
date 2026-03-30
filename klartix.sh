#!/bin/bash
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

TOTAL_STEPS=16
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
        warn "Installation failed or interrupted — cleaning up..."
    fi
    sync 2>/dev/null || true
    # Unmount chroot bind mounts first (arch-chroot leaves these if interrupted).
    # Must happen before fuser/umount or we'd kill host processes that have /dev open.
    for bind in dev/pts dev sys proc run; do
        umount "$TARGET_MOUNT/$bind" 2>/dev/null || umount -l "$TARGET_MOUNT/$bind" 2>/dev/null || true
    done
    umount "$TARGET_MOUNT/efi"  2>/dev/null || umount -l "$TARGET_MOUNT/efi"  2>/dev/null || true
    [ -n "$HOME_PART" ] && { umount "$TARGET_MOUNT/home" 2>/dev/null || umount -l "$TARGET_MOUNT/home" 2>/dev/null || true; }
    umount "$TARGET_MOUNT"      2>/dev/null || umount -l "$TARGET_MOUNT"      2>/dev/null || true
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
echo "  Init:         $TARGET_INI"
echo "  Kernel:       $KERNEL"
echo "  FS:           $TARGET_FS"
echo "  Target:       $TARGET_DISK"
echo "  EFI size:     $EFI_SIZE"
echo "  Root:         single partition"
echo "  Swap:         zram"
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
# shellcheck disable=SC2086
pacman -S $PKGS --noconfirm --needed
# to adapt if using a different PM

show_progress "Cleaning up previous installation attempts..."
rm -rf /tmp/artix-bootstrap*

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
    ext4)  mkfs.ext4  -F "$ROOT_PART" ;;
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
show_progress "Downloading Artix bootstrap tool..."
cd /tmp || exit
wget https://gitea.artixlinux.org/artix/artix-bootstrap/raw/branch/master/artix-bootstrap.sh

show_progress "Setting bootstrap tool permissions..."
chmod +x artix-bootstrap.sh

show_progress "Bootstrapping Artix Linux with $TARGET_INI..."
if [ -n "$MIRROR_URL" ]; then
    info "Using mirror: $MIRROR_URL"
    ./artix-bootstrap.sh -r "$MIRROR_URL" -i "$TARGET_INI" "$TARGET_MOUNT"
else
    ./artix-bootstrap.sh -i "$TARGET_INI" "$TARGET_MOUNT"
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

# Console keymap & font
case "$TARGET_INI" in
    openrc)
        echo "keymap=\"$VCONSOLE_KB\""    > /etc/conf.d/keymaps
        echo "windowkeys=\"YES\""          >> /etc/conf.d/keymaps
        echo "extended_keymaps=\"\""       >> /etc/conf.d/keymaps
        echo "consolefont=\"$VCONSOLE_FONT\"" > /etc/conf.d/consolefont
        ;;
    runit|s6|dinit)
        echo "KEYMAP=$VCONSOLE_KB"  > /etc/vconsole.conf
        echo "FONT=$VCONSOLE_FONT" >> /etc/vconsole.conf
        ;;
esac

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

# Kernel, bootloader & base packages
echo "Installing kernel and base packages..."
pacman -S --noconfirm \
    $KERNEL linux-firmware \
    grub efibootmgr mkinitcpio \
    sudo \
    git vim

# User
useradd -m -s /bin/bash -G wheel "$TARGET_USER"
echo "$TARGET_USER:$USER_PASSWORD" | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# Init-specific NetworkManager package
case "$TARGET_INI" in
    openrc)
        pacman -S --noconfirm networkmanager-openrc
        rc-update add NetworkManager default
        ;;
    runit)
        pacman -S --noconfirm networkmanager-runit
        ln -s /etc/runit/sv/NetworkManager /etc/runit/runsvdir/default/
        ;;
    s6)
        pacman -S --noconfirm networkmanager-s6
        s6-rc-bundle-update add default NetworkManager
        ;;
    dinit)
        pacman -S --noconfirm networkmanager-dinit
        dinitctl enable NetworkManager
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
sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect modconf block keyboard keymap consolefont filesystems fsck)/' /etc/mkinitcpio.conf
mkinitcpio -P

# GRUB
grub-install --target=x86_64-efi --efi-directory=/efi --boot-directory=/efi --removable
grub-mkconfig -o /efi/grub/grub.cfg

# Lock root if configured
if [ "$LOCK_ROOT" = "1" ]; then
    passwd -l root
    echo "Root account locked. Use sudo from $TARGET_USER."
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
info "Init system:  $TARGET_INI"
info "Kernel:       $KERNEL"
info "User:         $TARGET_USER"
info "Swap:         zram"
