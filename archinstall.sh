#!/usr/bin/env bash

RED='\e[0;31m'          # Red
GREEN='\e[1;32m'        # Green
BLUE='\e[0;34m'         # Blue
CYAN='\e[0;36m'         # Cyan
WHITE='\e[0;37m'        # White
END='\e[0m'
LOG=installation.log

export LC_ALL=""
export LC_COLLATE=C
export LANG=fr_FR.UTF-8
LANG=fr_FR.UTF-8

echo ""
echo -e $CYAN":: Installation d'ArchLinux"$END
echo ""
sleep 3
touch $LOG

ln -s /usr/share/zoneinfo/Europe/Paris /etc/localtime
echo -e $GREEN":: Configuration des locales"$END
echo "fr_FR.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo LANG=fr_FR.UTF-8 > /etc/locale.conf
export LANG=fr_FR.UTF-8
echo KEYMAP=fr >> /etc/vconsole.conf

parts_gpt(){
    echo -e $GREEN":: Création de la table de partition"$END
    parted -s /dev/sda mklabel gpt
    echo -e $GREEN":: Création de l'esp"$END
    parted -s /dev/sda mkpart primary 1Mib 250Mib
    parted -s /dev/sda set 1 boot on
    echo -e $GREEN":: Création de la partition /"$END
    parted -s /dev/sda mkpart primary 250Mib 100%
    RET="gpt"
    export $RET
    }

parts_msdos(){
    #cfdisk /dev/sda
    echo -e $GREEN":: Création de la table de partition"$END
    parted -s /dev/sda mklabel msdos
    echo -e $GREEN":: Création de la partition boot"$END
    parted -s /dev/sda mkpart primary 1Mib 250Mib
    parted -s /dev/sda set 1 boot on
    echo -e $GREEN":: Création de la partition /"$END
    parted -s /dev/sda mkpart primary 250Mib 100%
    RET="msdos"
    export $RET
    }




enc(){
    echo -e $GREEN":: Chiffrement du disque"$END
    cryptsetup -c aes-xts-plain -y -s 512 luksFormat /dev/sda2
    if [ $? = 0 ];then
        echo -e $GREEN":: Ouverture du disque"$END
        cryptsetup luksOpen /dev/sda2 sda2_crypt
        modprobe dm-mod
        echo -e $GREEN":: Création du volume physique"$END
        pvcreate /dev/mapper/sda2_crypt
        echo -e $GREEN":: Création du groupe de volume"$END
        vgcreate CryptGroup /dev/mapper/sda2_crypt
        echo -e $GREEN":: Création des volumes logiques (swap & /)"$END
        lvcreate -C y -L 4G CryptGroup -n lvswap
        lvcreate -l +100%FREE CryptGroup -n lvarch
        if [ $RET = "gpt" ]; then
          echo -e $GREEN":: Appliquation du systeme de fichier pour /boot/efi"$END
          mkfs.fat -F32 /dev/sda1

        else
          echo -e $GREEN":: Appliquation du systeme de fichier pour /boot"$END
          mkfs.ext4 -q /dev/sda1
        fi
          echo -e $GREEN":: Appliquation du systeme de fichier pour swap"$END
          mkswap  /dev/mapper/CryptGroup-lvswap -L swap
          echo -e $GREEN":: Appliquation du systeme de fichier pour /"$END
          mkfs.ext4 -q /dev/mapper/CryptGroup-lvarch -L arch
    else
        echo -e $RED":: Erreur de Chiffrement !"$END
        exit
    fi
    }

hop(){
    echo -e $GREEN":: Montage de la partition racine sur /mnt$END"
    mount /dev/mapper/CryptGroup-lvarch /mnt
    echo -e $GREEN":: Activation du swap"$END
    swapon /dev/mapper/CryptGroup-lvswap
    if [ $RET = "msdos" ]; then
      echo -e $GREEN":: Création du repertoir /boot"$END
      mkdir /mnt/boot
      echo -e $GREEN":: Montage de la partition /boot"$END
      mount /dev/sda1 /mnt/boot

    else
      echo -e $GREEN":: Création du répertoire /boot/efi"$END
      mkdir -p /mnt/boot/efi
      echo -e $GREEN":: Montage de l'esp"$END
      mount /dev/sda1 /mnt/boot/efi
      echo -e $GREEN":: Création du répertoire Archlinux"$END
      mkdir -p /mnt/boot/efi/EFI/arch
      echo -e $GREEN":: Automatisation"$END
      echo "[Unit]
Description=Copie du noyau dans l'ESP

[Path]
PathChanged=/boot/vmlinuz-linux
PathChanged=/boot/initramfs-linux.img
PathChanged=/boot/initramfs-linux-fallback.img

[Install]
WantedBy=multi-user.target" >> /etc/systemd/system/efistub-update.path
    echo "[Unit]
Description=Copie du noyau dans l'ESP

[Service]
Type=oneshot
ExecStart=/usr/bin/cp -f /boot/vmlinuz-linux /boot/efi/EFI/arch/vmlinuz-linux.efi
ExecStart=/usr/bin/cp -f /boot/initramfs-linux.img /boot/initramfs-linux-fallback.img /boot/efi/EFI/arch/

" >> /etc/systemd/system/efistub-update.service
    echo -e $GREEN":: Activation des services"$END
    systemctl enable efistub-update.path
  fi
    echo -e $GREEN":: Installation du systeme de base"$END
    pacstrap /mnt base #base-devel
    }

fchroot(){
    echo -e $GREEN":: Configuration de /etc/fstab"$END
    genfstab -U -p /mnt  >> /mnt/etc/fstab
    echo -e $GREEN":: Chroot..."$END
    echo -e $GREEN":: Copie du script chroot"$END
    cp -v chroot.sh /mnt/
    chmod +x /mnt/chroot.sh
    arch-chroot /mnt ./chroot.sh $RET
}

while getopts "bg" opt; do
  case $opt in
    b)  parts_msdos
        enc
        hop
        fchroot
        ;;
    g)  parts_gpt
        enc
        hop
        fchroot
        ;;
    \?  echo "Options:"
        echo "   -b: Bios installation"
        echo "   -g: UEFI installation"
        exit 1
        ;;
  esac
done
