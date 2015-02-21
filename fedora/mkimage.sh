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
  releasever=23
  repoids=fedora-rawhide
else
  releasever=$version
  repoids=fedora,fedora-updates
fi

scriptdir=$(cd "$(dirname "$0")" && pwd)

cachedir=/var/cache/yum/x86_64/$releasever
config=$scriptdir/fedora-$version-x86_64.conf
installroot=/var/tmp/fedora-$version-x86_64
reposdir=$scriptdir

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
  --setopt=override_install_langs=en_US \
  --setopt=reposdir="$reposdir" \
  --setopt=tsflags=nodocs \
  install @core

localedef --prefix "$installroot" --list-archive | \
  grep -a -v en_US.utf8 | \
  xargs localedef --prefix "$installroot" --delete-from-archive
mv "$installroot"/usr/lib/locale/locale-archive{,.tmpl}
chroot "$installroot" /usr/sbin/build-locale-archive

find "$installroot"/usr/share/i18n/locales -mindepth 1 -maxdepth 1 -not -name en_US -exec rm -rf {} +
find "$installroot"/usr/share/i18n/charmaps -mindepth 1 -maxdepth 1 -not -name UTF-8.gz -exec rm -rf {} +

yum --config="$config" --installroot="$installroot" history new
rm -rf "$installroot"/var/lib/yum/{yumdb,history}/*
truncate -c -s 0 "$installroot"/var/log/yum.log

for config in "$installroot"/etc/yum.conf "$installroot"/etc/dnf/dnf.conf; do
  if [[ -f "$config" ]]; then
    awk '
    (NF==0 && !done) { print "tsflags=nodocs"; done=1 } { print }
    END { if (!done) print "tsflags=nodocs" }
    ' "$config" > "$config".new
    mv "$config"{.new,}
  fi
done

echo '%_install_langs en_US' > "$installroot"/etc/rpm/macros.mkimage

rm -rf "$installroot"/{boot,media,mnt,tmp}/*
rm -f "$installroot$cachedir"

tar c -C "$installroot" . | docker import - "$repository:$version"
