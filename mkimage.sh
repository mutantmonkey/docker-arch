#!/usr/bin/zsh
set -e

(( EUID == 0 )) || {
    echo "This script requires root privileges"
    exit 1
}

(hash arch-chroot &>/dev/null && hash pacstrap &>/dev/null) || {
    echo "This script requires arch-chroot and pacstrap from arch-install-scripts"
    exit 1
}

hash expect &>/dev/null || {
    echo "This script requires expect"
    exit 1
}

rootfs=$(mktemp -d ${TMPDIR:-/var/tmp}/rootfs-archlinux-XXXXXXXXXX)
ignore_packages=(
    cryptsetup
    device-mapper
    groff
    iproute2
    jfsutils
    linux
    lvm2
    man-db
    man-pages
    mdadm
    nano
    netctl
    openresolv
    pciutils
    pcmciautils
    reiserfsprogs
    s-nail
    usbutils
    xfsprogs
)

# install only the base packages we need with pacstrap
expect <<EOF
  set send_slow {1 .1}
  proc send {ignore arg} {
      sleep .1
      exp_send -s -- \$arg
  }
  set timeout 60

  spawn pacstrap -GMcdi $rootfs base curl haveged git --ignore ${ignore_packages// /,}
  expect {
      -exact "anyway? \[Y/n\] " { send -- "n\r"; exp_continue }
      -exact "(default=all): " { send -- "\r"; exp_continue }
      -exact "installation? \[Y/n\]" { send -- "y\r"; exp_continue }
  }
EOF

# set timezone to UTC
ln -sf /usr/share/zoneinfo/UTC $rootfs/etc/localtime

# generate and set locale
echo 'en_US.UTF-8 UTF-8' > $rootfs/etc/locale.gen
echo 'LANG="en_US.UTF-8"' > $rootfs/etc/locale.conf
arch-chroot $rootfs locale-gen

# create pacman mirrorlist
echo "Server = https://mirrors.kernel.org/archlinux/\$repo/os/\$arch" > $rootfs/etc/pacman.d/mirrorlist

# create pacman keyring; pkill gpg-agent so it cleans up its socket
arch-chroot $rootfs /bin/sh -c "haveged -w 1024; pacman-key --init; pkill haveged; pacman -Rs --noconfirm haveged; pacman-key --populate archlinux; pkill gpg-agent"

echo "Building and compressing archive..."
tar --numeric-owner --create --auto-compress --file rootfs.tar.xz --directory "$rootfs" --transform='s,^./,,' .

echo "Cleaning up..."
rm -rf $rootfs

echo "Done."
