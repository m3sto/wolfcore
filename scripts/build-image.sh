#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${REPO_ROOT}/config/build.conf"

ROOTFS_ABS="${REPO_ROOT}/${ROOTFS_DIR}"
IMAGE_ABS="${REPO_ROOT}/${IMAGE_PATH}"
MNT_ABS="${REPO_ROOT}/${LOOP_MOUNT_DIR}"

if [[ "${EUID}" -ne 0 ]]; then
  echo "[ERR] root olarak çalıştırın." >&2
  exit 1
fi

if [[ ! -d "${ROOTFS_ABS}" ]]; then
  echo "[ERR] Rootfs yok: ${ROOTFS_ABS}" >&2
  echo "Önce: ./scripts/build-rootfs.sh" >&2
  exit 1
fi

mkdir -p "${REPO_ROOT}/out" "${MNT_ABS}"
rm -f "${IMAGE_ABS}"

echo "[INFO] ${IMAGE_SIZE_MB}MB disk imajı oluşturuluyor..."
qemu-img create -f raw "${IMAGE_ABS}" "${IMAGE_SIZE_MB}M" >/dev/null

parted -s "${IMAGE_ABS}" mklabel gpt
parted -s "${IMAGE_ABS}" mkpart primary ext4 1MiB 100%
parted -s "${IMAGE_ABS}" set 1 bios_grub on
parted -s "${IMAGE_ABS}" set 1 legacy_boot on

LOOP_DEV="$(losetup --find --show --partscan "${IMAGE_ABS}")"
PART_DEV="${LOOP_DEV}p1"

cleanup() {
  set +e
  umount -lf "${MNT_ABS}/dev" 2>/dev/null
  umount -lf "${MNT_ABS}/proc" 2>/dev/null
  umount -lf "${MNT_ABS}/sys" 2>/dev/null
  umount -lf "${MNT_ABS}" 2>/dev/null
  losetup -d "${LOOP_DEV}" 2>/dev/null
}
trap cleanup EXIT

mkfs.ext4 -F -L wolfcore-root "${PART_DEV}" >/dev/null
mount "${PART_DEV}" "${MNT_ABS}"

rsync -aHAX --numeric-ids "${ROOTFS_ABS}/" "${MNT_ABS}/"
mkdir -p "${MNT_ABS}/boot/grub" "${MNT_ABS}/EFI/BOOT"

mount --bind /dev "${MNT_ABS}/dev"
mount --bind /proc "${MNT_ABS}/proc"
mount --bind /sys "${MNT_ABS}/sys"

chroot "${MNT_ABS}" grub-install --target=i386-pc --recheck "${LOOP_DEV}"
chroot "${MNT_ABS}" grub-install --target=x86_64-efi --efi-directory=/ --boot-directory=/boot --removable --recheck
chroot "${MNT_ABS}" update-grub

echo "[OK] İmaj hazır: ${IMAGE_ABS}"
