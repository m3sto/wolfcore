#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${REPO_ROOT}/config/build.conf"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "[ERR] Gerekli komut bulunamadı: $1" >&2
    exit 1
  }
}

if [[ "${EUID}" -ne 0 ]]; then
  echo "[ERR] root olarak çalıştırın." >&2
  exit 1
fi

for cmd in debootstrap mount umount chroot rsync xargs; do
  require_cmd "${cmd}"
done

mkdir -p "${REPO_ROOT}/out"
rm -rf "${REPO_ROOT}/${ROOTFS_DIR}"
mkdir -p "${REPO_ROOT}/${ROOTFS_DIR}"

echo "[INFO] debootstrap rootfs oluşturuluyor..."
debootstrap --arch="${ARCH}" "${DIST_CODENAME}" "${REPO_ROOT}/${ROOTFS_DIR}" "${MIRROR}"

cp "${REPO_ROOT}/config/packages.list" "${REPO_ROOT}/${ROOTFS_DIR}/tmp/packages.list"

cat > "${REPO_ROOT}/${ROOTFS_DIR}/tmp/provision.sh" <<CHROOT
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get update
xargs -a /tmp/packages.list apt-get install -y --no-install-recommends
apt-get install -y --no-install-recommends ${KERNEL_PACKAGE}

echo "${HOSTNAME}" > /etc/hostname
printf "127.0.0.1\tlocalhost\n127.0.1.1\t${HOSTNAME}\n" > /etc/hosts

echo "root:${ROOT_PASSWORD}" | chpasswd

systemctl enable NetworkManager
systemctl enable getty@tty1

if [[ -f /etc/default-grub.wolfcore ]]; then
  cp /etc/default-grub.wolfcore /etc/default/grub
fi

update-initramfs -u -k all || true
update-grub || true

if ! command -v grub-install >/dev/null 2>&1; then
  echo "[ERR] grub-install bulunamadı. grub2-common/grub-*-bin paketlerini kontrol edin." >&2
  exit 1
fi

apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/packages.list /tmp/provision.sh
CHROOT

chmod +x "${REPO_ROOT}/${ROOTFS_DIR}/tmp/provision.sh"

mount --bind /dev "${REPO_ROOT}/${ROOTFS_DIR}/dev"
mount --bind /proc "${REPO_ROOT}/${ROOTFS_DIR}/proc"
mount --bind /sys "${REPO_ROOT}/${ROOTFS_DIR}/sys"

cleanup() {
  set +e
  umount -lf "${REPO_ROOT}/${ROOTFS_DIR}/dev" 2>/dev/null
  umount -lf "${REPO_ROOT}/${ROOTFS_DIR}/proc" 2>/dev/null
  umount -lf "${REPO_ROOT}/${ROOTFS_DIR}/sys" 2>/dev/null
}
trap cleanup EXIT

rsync -a "${REPO_ROOT}/overlays/rootfs/" "${REPO_ROOT}/${ROOTFS_DIR}/"

chroot "${REPO_ROOT}/${ROOTFS_DIR}" /tmp/provision.sh

echo "[OK] Rootfs hazır: ${REPO_ROOT}/${ROOTFS_DIR}"
