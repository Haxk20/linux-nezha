#!/bin/sh

SD_CARD=Nezha.img
dd if=/dev/zero of=${SD_CARD} bs=1M count=8000
echo "Create new GPT parititon table and partitions"
parted -s -a optimal -- ${SD_CARD} mklabel gpt
parted -s -a optimal -- ${SD_CARD} mkpart primary ext2 128MiB 540MiB
parted -s -a optimal -- ${SD_CARD} mkpart primary linux-swap 540MiB 2540MiB
parted -s -a optimal -- ${SD_CARD} mkpart primary ext4 2540MiB 100%

loopdevice=`sudo losetup -f --show ${SD_CARD}`
device=`sudo kpartx -va $loopdevice | sed -E 's/.*(loop[0-9])p.*/\1/g' | head -1`
device="/dev/mapper/${device}"
boot="${device}p1"
swap="${device}p2"
root="${device}p3"

echo "Write SPL"
dd conv=notrunc if=sun20i_d1_spl/nboot/boot0_sdcard_sun20iw1p1.bin of=${SD_CARD} bs=8192 seek=16
echo "Write u-boot table of contents"
dd conv=notrunc if=u-boot.toc1 of=${SD_CARD} bs=512 seek=32800

mkdir -p boot
mkdir -p rootfs

sudo mkfs.ext4 $boot
echo "Copy files to /boot partition"
sudo mount -t ext4  $boot boot

echo "Copy kernel to boot partition"
sudo cp -rfv linux/arch/riscv/boot/Image.gz boot
echo "Copy boot script to boot partition"
sudo cp -rfv boot.scr boot
echo "Copy device tree to boot partition"
sudo cp -rfv linux/arch/riscv/boot/dts/allwinner/sun20i-d1-nezha.dtb boot

echo "Sync files on disks"
sudo sync
echo "Unmounting boot partition"
sudo umount boot

echo "Downloading Arch linux rootfs"
wget https://riscv.mirror.pkgbuild.com/images/archriscv-20220727.tar.zst

mkdir rootfs_distro
tar -I zstd -xvf archriscv-20220727.tar.zst -C rootfs_distro

echo "Copy files to root filesystem"
sudo mkfs.ext4 $root
sudo mount -t ext4 $root rootfs
sudo cp -av rootfs_distro/* rootfs/
sudo cp fstab rootfs/etc/fstab
sudo sync
sudo umount rootfs

sudo mkswap $swap


echo "Cleaning up after ourselves"
sudo kpartx -d $loopdevice
sudo losetup -d $loopdevice
sudo rm -rf boot
sudo rm -rf rootfs
