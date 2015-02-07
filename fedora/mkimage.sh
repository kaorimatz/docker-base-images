#!/bin/bash

set -e
set -u

usage() {
  cat <<EOF
Usage:
  $(basename "$0") REPOSITORY

Options:
  [--release-version=VERSION]   Specify Fedora release version
                                Default: rawhide
EOF
}

options=$(getopt -o '' -l release-version:,help -- "$@" 2> /dev/null)
if [[ $? -ne 0 ]]
then
  usage "$(basename "$0")"
  exit 1
fi
eval set -- "$options"

while :
do
  case "$1" in
    --release-version)
      version=$2
      shift 2;;
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
[[ -n "$version" ]] || version=rawhide

if [[ "$version" == 'rawhide' ]]
then
  releasever=22
  repoids=rawhide
else
  releasever=$version
  repoids=fedora,updates
fi

cachedir=/var/cache/yum/x86_64/$releasever
scriptdir=$(cd "$(dirname "$0")" && pwd)
config=$scriptdir/fedora-$version-x86_64.conf
installroot=/var/tmp/fedora-$version-x86_64

rm -rf "$installroot"
mkdir -p "$installroot"

for dev in console null urandom
do
  MAKEDEV -v -d "$installroot"/dev -x "$dev"
done

mkdir -p "$cachedir"
mkdir -p "$installroot/$(dirname "$cachedir")"
ln -sf "$cachedir" "$installroot$cachedir"

yum -y \
  --config="$config" \
  --disablerepo='*' \
  --enablerepo="$repoids" \
  --installroot="$installroot" \
  --nogpgcheck \
  --releasever="$releasever" \
  --setopt=cachedir="$cachedir" \
  --setopt=group_package_types=mandatory \
  --setopt=tsflags=nodocs \
  --setopt=override_install_langs=en_US \
  install @core

localedef --prefix "$installroot" --list-archive | \
  grep -a -v en_US.utf8 | \
  xargs localedef --prefix "$installroot" --delete-from-archive
mv "$installroot"/usr/lib/locale/locale-archive{,.tmpl}
chroot "$installroot" /usr/sbin/build-locale-archive

mv "$installroot"/usr/share/i18n/locales/en_US /tmp
rm -rf "$installroot"/usr/share/i18n/locales/*
mv /tmp/en_US "$installroot"/usr/share/i18n/locales/

yum --config="$config" --installroot="$installroot" history new
rm -rf "$installroot"/var/lib/yum/{yumdb,history}/*
truncate -c -s 0 "$installroot"/var/log/yum.log

rm -rf "$installroot"/{boot,media,mnt,tmp}/*
rm -f "$installroot$cachedir"

tar c -C "$installroot" . | docker import - "$repository:$version"
