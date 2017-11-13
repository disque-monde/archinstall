#!/usr/bin/env bash

## decommenter dans /etc/default/grub #cryptodisk

RET=$1

GREEN='\e[1;32m'        # Green
BLUE='\e[0;34m'         # Blue
CYAN='\e[0;36m'         # Cyan
WHITE='\e[0;37m'        # White
END='\e[0m'

export LC_ALL=""
export LC_COLLATE=C

LANG=fr_FR.UTF-8
export LANG=fr_FR.UTF-8
read -p 'Hostname: ' HOSTNAME
echo -e "Hostname: $HOSTNAME"

pacman-db-upgrade
echo $HOSTNAME >> /etc/hostname
ln -s /usr/share/zoneinfo/Europe/Paris /etc/localtime
echo -e $GREEN":: Configuration des locales"$END
echo "fr_FR.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo LANG=fr_FR.UTF-8 > /etc/locale.conf
export LANG=fr_FR.UTF-8
echo KEYMAP=fr >> /etc/vconsole.conf
echo -e $GREEN":: Configuration du fichier mkinitcpio.conf"$END
sed -i '7s/""/"sd-mod" /' /etc/mkinitcpio.conf
sed -i '52s/\(block \)/\1 keymap encrypt lvm2 resume /' /etc/mkinitcpio.conf
echo -e $GREEN":: Création de la ramdisk"$END
mkinitcpio -p linux
echo -e $GREEN":: Installation de GRUB"$END
pacman -S grub os-prober -y
if [ $RET = "gpt" ]; then
  pacman -S efibootmgr -y
  grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=arch_grub --recheck
else
  grub-install --boot-directory=/boot --no-floppy --recheck /dev/sda
fi
cp /usr/share/grub/{unicode.pf2,ascii.pf2} /boot/grub
echo -e $GREEN":: Configuration de grub"$END
sed -i '6s/"quiet"/"verbose" /' /etc/default/grub
sed -i '7s/""/"cryptdevice\=\/dev\/sda2\:sda2_crypt resume\=\/dev\/mapper\/CryptGroup\-lvswap pcie\_aspm\=force elevator\=noop" /' /etc/default/grub
echo -e $GREEN"Géneration de grub.cfg"$END
grub-mkconfig -o /boot/grub/grub.cfg
echo -e $GREEN"Mot de passe pour root:"$END
passwd root
echo -e $GREEN"Ajout d'un utilisateur"
read -p 'Utilisateur: ' USER1
useradd -g users -m $USER1
passwd $USER1

read -p 'Voulez vous installer des programmes supplèmenaire ? (Y/N)' REP
if [ $REP = "Y" ]; then
  ./post.sh
else
  reboot
fi
