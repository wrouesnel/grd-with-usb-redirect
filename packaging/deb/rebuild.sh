#!/usr/bin/env bash
# Rebuilds an Ubuntu package with our patches, as a source package for a PPA.
#
# Usage: rebuild.sh <package dir> <series> <output dir> [--binary]
#   <package dir>/<series>/ holds target.conf, the *.patch files to add, and an
#   optional prepare.sh that runs in the unpacked source after they're added.
#   --binary also builds the .debs, to test before uploading.
#
# The source package is unsigned; sign it with debsign before dput.
set -euo pipefail
pkgdir=$(cd "$1" && pwd); series=$2
out=$(mkdir -p "$3" && cd "$3" && pwd); binary=${4:-}
target="$pkgdir/$series"
# shellcheck source=/dev/null
. "$target/target.conf"
image=docker.io/library/ubuntu:$series
maint="${DEBFULLNAME:-Will Rouesnel} <${DEBEMAIL:?set DEBEMAIL to the uploader email}>"

podman run --rm -i -v "$target:/target:ro,Z" -v "$out:/out:Z" \
    -e SOURCE="$SOURCE" -e VERSION="$VERSION" -e REVISION="$REVISION" \
    -e CHANGES="$CHANGES" -e SERIES="$series" -e MAINT="$maint" -e BINARY="$binary" \
    "$image" bash -euo pipefail <<'SCRIPT'
export DEBIAN_FRONTEND=noninteractive
echo 'Acquire::Retries "10"; Acquire::http::Timeout "30";' > /etc/apt/apt.conf.d/80retries
sed -i 's/^Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/ubuntu.sources
apt-get -qq update
apt-get -qq install -y --no-install-recommends dpkg-dev devscripts quilt fakeroot >/dev/null
mkdir /build && cd /build
apt-get source -qq --only-source "$SOURCE=$VERSION" >/dev/null
cd "$(find . -mindepth 1 -maxdepth 1 -type d | head -1)"
mkdir -p debian/patches/grd-with-usb-redirect
for p in /target/*.patch; do
    cp "$p" debian/patches/grd-with-usb-redirect/
    echo "grd-with-usb-redirect/$(basename "$p")" >> debian/patches/series
done
if [ -x /target/prepare.sh ]; then /target/prepare.sh; fi
DEBFULLNAME=${MAINT% <*} DEBEMAIL=${MAINT#*<}; DEBEMAIL=${DEBEMAIL%>}
export DEBFULLNAME DEBEMAIL
dch -v "$VERSION+grdusb$REVISION" -D "$SERIES" --force-distribution "$CHANGES"
QUILT_PATCHES=debian/patches quilt push -aq >/dev/null
QUILT_PATCHES=debian/patches quilt pop -aq >/dev/null
rm -rf .pc
# debian/rules clean, run for the source package too, needs the build dependencies.
apt-get -qq build-dep -y ./ >/dev/null
dpkg-buildpackage -S -sd -d -us -uc >/out/"$SOURCE"-source.log 2>&1 || { tail -30 /out/"$SOURCE"-source.log; exit 1; }
cp ../*.dsc ../*.debian.tar.* ../*_source.changes ../*_source.buildinfo /out/
if [ -n "$BINARY" ]; then
    dpkg-buildpackage -b -us -uc >/out/"$SOURCE"-binary.log 2>&1 || { tail -60 /out/"$SOURCE"-binary.log; exit 1; }
    cp ../*.deb /out/
fi
SCRIPT
ls "$out"
