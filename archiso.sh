$!/bin/bash

# You're gonna want to change this to your own stuff and obv make sure you aren't nuking your FS
DISK=/dev/nvme0n1
INSTALL_DISK="$DISK"p3
VG_ID=arch
D_SWAP=/dev/"$VG_ID"/swap
D_ROOT=/dev/"$VG_ID"/root
DEVEFI="$DISK"p2

HOSTNAME=m1lkyw4y

# format drive
pvcreate $INSTALL_DISK
vgcreate $VG_ID $INSTALL_DISK
lvcreate -L 8G $VG_ID -n swap
lvcreate -l +100%FREE $VG_ID -n root
lvdisplay

mkswap -L swap $D_SWAP
mkfs.ext4 $D_ROOT
mount $D_ROOT /mnt
swapon $D_SWAP

mkdir /mnt/efi
mkfs.fat -F32 $DEVEFI
mount $DEVEFI /mnt/efi

# install base packages
pacstrap -i /mnt \
	base base-devel linux linux-firmware lvm2 grub efibootmgr \
       	dhcpcd net-tools dialog openssh \
	vim git ansible

# generate fstab
genfstab -U -p /mnt >> /mnt/etc/fstab
less /mnt/etc/fstab

# chroot
arch-chroot /mnt /bin/bash

# localization
export LANG=en_US.UTF-8
echo $LANG UTF-8 >> /etc/locale.gen
locale-gen
echo LANG=$LANG > /etc/locale.conf

# timezone
ln -fs /usr/share/zoneinfo/America/Detroit /etc/localtime
hwclock --systohc --utc

# hostname
echo $HOSTNAME > /etc/hostname

# mkinitcpio
sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect modconf block lvm2 filesystems keyboard fsck)/' /etc/mkinitcpio.conf
mkinitcpio -P

# grub
sed -i 's/^GRUB_PRELOAD_MODULES=.*/GRUB_PRELOAD_MODULES="part_gpt part_msdos lvm"/' /etc/default/grub
grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=GRUB --recheck --removable
grub-install --target=i386-pc --recheck $DISK
grub-mkconfig -o /boot/grub/grub.cfg

# leave chroot
exit
umount -R /mnt

# done
echo "Remember to set your password with passwd then reboot"
