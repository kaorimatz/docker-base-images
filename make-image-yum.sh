#!/bin/bash

set -e
set -u

usage() {
  cat <<EOF
Usage:
  $(basename "$0") --os-name=OS_NAME --os-version=OS_VERSION REPOSITORY

Options:
  --os-name=OS_NAME         Specify OS name
  --os-version=OS_VERSION   Specify OS version
EOF
}

options=$(getopt -o '' -l os-name:,os-version:,help -- "$@" 2> /dev/null)
if [[ $? -ne 0 ]]
then
  usage "$(basename "$0")"
  exit 1
fi
eval set -- "$options"

while :
do
  case "$1" in
    --os-name)
      os_name=$2
      shift 2;;
    --os-version)
      os_version=$2
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

[[ -n "$os_name" ]] || ( usage; exit 1 )
[[ -n "$os_version" ]] || ( usage; exit 1 )
[[ -n "$repository" ]] || ( usage; exit 1 )

case "$os_name" in
  fedora)
    if [[ "$os_version" == 'rawhide' ]]
    then
      releasever=23
      repoids=fedora-rawhide
    else
      releasever=$os_version
      repoids=fedora,fedora-updates
    fi
    ;;
  centos)
    releasever=$os_version
    repoids=centos-base,centos-updates,centos-extras
    ;;
  *)
    echo "Unknown OS name: $os_name"
    exit 1
esac

scriptdir=$(cd "$(dirname "$0")" && pwd)

cachedir=/var/cache/yum/x86_64/$releasever
config=$scriptdir/${os_name}-${os_version}-x86_64.conf
installroot=/var/tmp/${os_name}-${os_version}-x86_64
reposdir=$scriptdir

rm -rf "$installroot"
mkdir -p "$installroot"

for dev in console null urandom
do
  MAKEDEV -v -d "$installroot"/dev -x "$dev"
done

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

tar c -C "$installroot" . | docker import - "$repository:$os_version"
