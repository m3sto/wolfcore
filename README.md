# Wolfcore (Modüler, kurulum gerektirmeyen Linux dağıtımı)

Bu depo, **disk imajını doğrudan diske yazıp boot edilebilen** (kurulum sihirbazı olmadan) bir Wolfcore dağıtımı üretmek için hazırlanmıştır.

## Hedef Özellikler

- ISO/IMG benzeri tek bir çıktı dosyasıyla çalışır.
- Çıktı doğrudan diske yazılır, kurulum ekranı yoktur.
- Varsayılan kullanıcı `root`.
- Varsayılan root parolası: `wolf`.
- Paket yönetimi: `apt-get` + `dpkg`.
- Konsolda profesyonel ağ yönetimi: `NetworkManager` + `nmcli` + `nmtui`.
- **UEFI + BIOS** boot desteği.
- **Tek bölüm (single partition)** mimarisi.

> Güvenlik notu: Varsayılan root parolası (`wolf`) ilk açılış sonrası hemen değiştirilmelidir.

---

## Mimarinin Özeti

1. `scripts/build-rootfs.sh`
   - Debian taban rootfs'i `debootstrap` ile üretir.
   - apt/dpkg, kernel, grub, NetworkManager, nmtui gibi bileşenleri kurar.
   - root parolasını `wolf` olarak ayarlar.

2. `scripts/build-image.sh`
   - Tek bölümlü disk imajı oluşturur (GPT + tek ext4 bölüm).
   - Rootfs'i bu bölüme kopyalar.
   - İçeride hem BIOS hem UEFI için GRUB kurar.

3. `overlays/rootfs/`
   - Rootfs içine kopyalanan kalıcı dosyalar.
   - Örn: otomatik konsol root login override dosyası.

---

## Gereksinimler

Host sistemde şu araçlar kurulu olmalıdır:

- `debootstrap`
- `qemu-utils`
- `parted`
- `gdisk`
- `e2fsprogs`
- `grub-pc-bin`
- `grub-efi-amd64-bin`
- `dosfstools`
- `rsync`

Debian/Ubuntu örnek:

```bash
sudo apt-get update
sudo apt-get install -y debootstrap qemu-utils parted gdisk e2fsprogs \
  grub-pc-bin grub-efi-amd64-bin dosfstools rsync
```

---

## Hızlı Kullanım

```bash
sudo ./scripts/build-rootfs.sh
sudo ./scripts/build-image.sh
```

Çıktı imajı varsayılan olarak `out/wolfcore.img` olur.

Diske yazdırma örneği (DİKKAT: veri siler):

```bash
sudo dd if=out/wolfcore.img of=/dev/sdX bs=4M status=progress conv=fsync
```

---

## Ağ Yönetimi (Konsol)

- Etkileşimli: `nmtui`
- Komut satırı: `nmcli`

Örnek:

```bash
nmcli device status
nmcli connection show
nmtui
```

---

## Notlar

- Bu tasarım bilinçli olarak tek bölüm yaklaşımı kullanır.
- UEFI boot dosyaları tek ext4 bölüm içinde `EFI/` dizinine kurulacak şekilde hedeflenir.
- Bazı firmware implementasyonları ayrı FAT ESP bekleyebilir. Bu repo, istenen tek-bölüm mimarisini önceliklendirir.
