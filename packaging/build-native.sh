#!/usr/bin/env bash
# Builds this repository's own packages (grd-with-usb-redirect,
# grd-headless-session and grd-no-lockscreen).
#
# Usage: DEBEMAIL=<address> packaging/build-native.sh <series> <output dir> [--binary]
#   <series> is noble or resolute for an Ubuntu source package, or el10 for a
#   source RPM. --binary also builds the packages, to test.
#
# Ubuntu source packages are unsigned; sign them with debsign before dput.
set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
series=$1; out=$(mkdir -p "$2" && cd "$2" && pwd); binary=${3:-}
version=$(sed -n 's/^Version: *//p' "$here/packaging/rpm/grd-with-usb-redirect.spec")
revision=${REVISION:-1}
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
src=$work/grd-with-usb-redirect-$version
mkdir -p "$src"
(cd "$here" && git ls-files -co --exclude-standard -z | xargs -0 cp --parents -t "$src")

case $series in
noble|resolute)
    : "${DEBEMAIL:?set DEBEMAIL to the uploader email}"
    case $series in noble) release=24.04 ;; resolute) release=26.04 ;; esac
    podman run --rm -i -v "$work:/work:Z" -v "$out:/out:Z" \
        -e DEBVER="$version~$release.$revision" -e SERIES="$series" -e BINARY="$binary" \
        -e DEBEMAIL="$DEBEMAIL" -e DEBFULLNAME="${DEBFULLNAME:-Will Rouesnel}" \
        "docker.io/library/ubuntu:$series" bash -euo pipefail <<'SCRIPT'
export DEBIAN_FRONTEND=noninteractive
echo 'Acquire::Retries "10"; Acquire::http::Timeout "30";' > /etc/apt/apt.conf.d/80retries
apt-get -qq update
apt-get -qq install -y --no-install-recommends build-essential dpkg-dev devscripts debhelper fakeroot >/dev/null
cp -r /work/grd-with-usb-redirect-* /build && cd /build
dch --create --package grd-with-usb-redirect -v "$DEBVER" -D "$SERIES" --force-distribution \
    "Build for Ubuntu $SERIES."
dpkg-buildpackage -S -d -us -uc >/out/native-source.log 2>&1 || { tail -30 /out/native-source.log; exit 1; }
cp ../*.dsc ../*.tar.* ../*_source.changes ../*_source.buildinfo /out/
if [ -n "$BINARY" ]; then
    dpkg-buildpackage -b -us -uc >/out/native-binary.log 2>&1 || { tail -40 /out/native-binary.log; exit 1; }
    cp ../*.deb /out/
fi
SCRIPT
    ;;
el10)
    tar -C "$work" -czf "$work/grd-with-usb-redirect-$version.tar.gz" "grd-with-usb-redirect-$version"
    podman run --rm -i -v "$work:/work:Z" -v "$out:/out:Z" -e BINARY="$binary" \
        docker.io/library/almalinux:10 bash -euo pipefail <<'SCRIPT'
dnf -y -q install rpm-build systemd-rpm-macros >/dev/null
mkdir -p ~/rpmbuild/SOURCES
cp /work/*.tar.gz ~/rpmbuild/SOURCES/
spec=$(ls /work/grd-with-usb-redirect-*/packaging/rpm/grd-with-usb-redirect.spec)
rpmbuild -bs "$spec" >/dev/null
cp ~/rpmbuild/SRPMS/*.src.rpm /out/
if [ -n "$BINARY" ]; then
    rpmbuild -bb "$spec" > /out/native-rpm.log 2>&1 || { tail -40 /out/native-rpm.log; exit 1; }
    cp ~/rpmbuild/RPMS/*/*.rpm /out/
fi
SCRIPT
    ;;
*) echo "unknown series $series" >&2; exit 2 ;;
esac
ls "$out"
