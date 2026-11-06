#!/usr/bin/env bash
# Rebuilds the distro's gnome-remote-desktop with our patch, in an EL10 container.
# Usage: build-rpm.sh <dir holding the source RPM> <output dir>
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
src=$(cd "$1" && pwd); out=$(mkdir -p "$2" && cd "$2" && pwd)
podman run --rm -v "$here:/patch:ro,Z" -v "$src:/src:ro,Z" -v "$out:/out:Z" \
    docker.io/library/almalinux:10 bash -euo pipefail -c '
dnf -y -q install dnf-plugins-core rpm-build rpmdevtools >/dev/null
dnf config-manager --set-enabled crb
dnf -y -q install epel-release >/dev/null
rpm -i /src/gnome-remote-desktop-*.src.rpm 2>/dev/null
cd ~/rpmbuild/SPECS
cp /patch/0001-*.patch ~/rpmbuild/SOURCES/
sed -i "/^Patch5:/a Patch6:         0001-rdp-Proxy-URBDRC-channels-to-usbgw-bridge.patch" gnome-remote-desktop.spec
dnf -y -q builddep gnome-remote-desktop.spec >/dev/null
rpmbuild -bb --define "dist .el10_2.usbgw" gnome-remote-desktop.spec > /out/build.log 2>&1 || { tail -40 /out/build.log; exit 1; }
cp ~/rpmbuild/RPMS/x86_64/gnome-remote-desktop-[0-9]*.rpm /out/
'
