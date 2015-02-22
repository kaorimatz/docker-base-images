#!/bin/bash

set -e
set -u

usage() {
  cat <<EOF
Usage:
  $(basename "$0") REPOSITORY
EOF
}

options=$(getopt -o '' -l help -- "$@" 2> /dev/null)
if [[ $? -ne 0 ]]
then
  usage "$(basename "$0")"
  exit 1
fi
eval set -- "$options"

while :
do
  case "$1" in
    --help)
      usage
      exit 0;;
    --)
      shift 1
      break;;
  esac
done

if [[ $# -lt 1 ]]; then
  usage "$(basename "$0")"
  exit 1
fi

repository=$1

[[ -n "$repository" ]] || ( usage; exit 1 )

scriptdir=$(cd "$(dirname "$0")" && pwd)

config=$scriptdir/archlinux-x86_64.conf
installroot=/var/tmp/archlinux-x86_64

rm -rf "$installroot"
mkdir -m 755 -p "$installroot"/var/lib/pacman

for dev in console null random urandom
do
  MAKEDEV -v -d "$installroot"/dev -x "$dev"
done

ln -s /proc/self/fd "$installroot"/dev/fd

pacman \
  --config="$config" \
  --noconfirm \
  --refresh \
  --root="$installroot" \
  --sync \
  bash grep haveged iproute2 iputils pacman procps-ng sed systemd vi

sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' "$installroot"/etc/locale.gen
chroot "$installroot" /usr/sbin/locale-gen

# Inverted pattern matches in NoExtract does not work in pacman 4.1.2 or earlier
find "$installroot"/usr/share/i18n/locales -mindepth 1 -maxdepth 1 -not -name en_US -exec rm -rf {} +
find "$installroot"/usr/share/i18n/charmaps -mindepth 1 -maxdepth 1 -not -name UTF-8.gz -exec rm -rf {} +
find "$installroot"/usr/share/locale -mindepth 1 -maxdepth 1 -not -name en_US -and -not -name locale.alias -exec rm -rf {} +

rm "$installroot"/var/lib/pacman/sync/*
truncate -c -s 0 "$installroot"/var/log/pacman.log

sed -i 's,^#\(Server = https://mirrors.kernel.org/.*\),\1,' "$installroot"/etc/pacman.d/mirrorlist
sed -i "s,^#NoExtract   =,$(grep NoExtract "$config" | tr '\n' '\000' | sed 's/\x0/\\n/g')," "$installroot"/etc/pacman.conf

chroot "$installroot" bash -s <<EOF
trap 'umount /proc' EXIT
mount -t proc proc /proc
pacman-db-upgrade
haveged -w 1024
pacman-key --init
pkill haveged
pacman --noconfirm --remove haveged
pacman-key --populate archlinux
pkill gpg-agent
EOF

rm -rf "$installroot"/{boot,mnt,tmp}/*

tar c -C "$installroot" . | docker import - "$repository":latest
