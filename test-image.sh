#!/bin/bash
# Test klartix.sh against a loop device
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/default.conf"

IMAGE_FILE="${1:-/tmp/artix-test.img}"

# Derive image size from conf: EFI + ROOT + 512MiB overhead, stripping the unit suffix
_to_mib() {
	local val="${1%%[A-Za-z]*}"
	local unit="${1#"$val"}"
	case "${unit,,}" in
	gib | g) echo $((val * 1024)) ;;
	mib | m) echo "$val" ;;
	*) echo $((val * 1024)) ;;
	esac
}
_IMAGE_MIB=$(($(_to_mib "$EFI_SIZE") + $(_to_mib "$ROOT_SIZE") + 512))
IMAGE_SIZE="${2:-${_IMAGE_MIB}MiB}"

[ "$(id -u)" -ne 0 ] && {
	echo "Must be run as root."
	exit 1
}

# Create sparse image
echo "[1/3] Creating sparse disk image: $IMAGE_FILE ($IMAGE_SIZE)..."
dd if=/dev/zero of="$IMAGE_FILE" bs=1 count=0 seek="$IMAGE_SIZE" 2>/dev/null

# Attach loop device
echo "[2/3] Attaching loop device..."
LOOP_DEV=$(losetup -f --show -P "$IMAGE_FILE")
echo "      Loop device: $LOOP_DEV"

cleanup() {
	rm -rf /tmp/artix-bootstrap*
	sync
}
trap cleanup EXIT

[[ "$LOOP_DEV" != /dev/loop* ]] && {
	echo "ERROR: $LOOP_DEV is not a loop device — aborting."
	exit 1
}

echo "[3/3] Launching klartix installer enter '$LOOP_DEV' as target disk"
echo ""
bash "$SCRIPT_DIR/klartix.sh"

chmod 644 "$IMAGE_FILE"
