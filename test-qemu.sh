#!/bin/sh
# test-qemu.sh - boot artix image in QEMU UEFI
# usage: ./test-qemu.sh [image]

IMG="${1:-/tmp/artix-test.img}"
OVMF_CODE="/usr/share/OVMF/OVMF_CODE.fd"
OVMF_VARS="/tmp/ovmf_vars.fd"

[ ! -f "$IMG" ] && {
	echo "Image not found: $IMG"
	exit 1
}
[ ! -f "$OVMF_VARS" ] && cp /usr/share/OVMF/OVMF_VARS.fd "$OVMF_VARS"

qemu-system-x86_64 \
	-enable-kvm \
	-machine q35,accel=kvm \
	-device intel-iommu \
	-cpu host \
	-smp 2 \
	-m 2G \
	-drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE" \
	-drive if=pflash,format=raw,file="$OVMF_VARS" \
	-drive file="$IMG",format=raw,if=virtio \
	-nic user \
	-display sdl,gl=on
