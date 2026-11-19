#!/usr/bin/env bash
# Rebuilds an EL10 package's source RPM with our patches, for COPR.
#
# Usage: rebuild-srpm.sh <package dir> <output dir> [--binary]
#   <package dir>/el10/ holds the *.patch files to add (named from 0100 up)
#   and target.conf. --binary also builds the RPMs, to test before uploading.
set -euo pipefail
pkgdir=$(cd "$1" && pwd); out=$(mkdir -p "$2" && cd "$2" && pwd); binary=${3:-}
target=$pkgdir/el10
# shellcheck source=/dev/null
. "$target/target.conf"

podman run --rm -i -v "$target:/target:ro,Z" -v "$out:/out:Z" \
    -e SOURCE="$SOURCE" -e VERSION="$VERSION" -e REVISION="$REVISION" \
    -e CHANGES="$CHANGES" -e PROVIDES="${PROVIDES:-}" -e RECOMMENDS="${RECOMMENDS:-}" -e BINARY="$binary" -e PACKAGER="${PACKAGER:-Will Rouesnel}" \
    docker.io/library/almalinux:10 bash -euo pipefail <<'SCRIPT'
dnf -y -q install dnf-plugins-core rpm-build rpmdevtools >/dev/null
dnf config-manager --set-enabled crb
dnf -y -q install epel-release >/dev/null
cd /tmp
dnf -q download --source "$SOURCE-$VERSION" >/dev/null
rpm -i "$SOURCE"-*.src.rpm 2>/dev/null
cd ~/rpmbuild/SPECS
spec=$SOURCE.spec
cp /target/*.patch ~/rpmbuild/SOURCES/
# Add our patches after the distro's, numbered from 100.
last=$(grep -n '^Patch[0-9]*:' "$spec" | tail -1 | cut -d: -f1)
for p in /target/*.patch; do
    n=$(basename "$p" | sed 's/^0*\([0-9]*\)-.*/\1/')
    sed -i "${last}a Patch$n: $(basename "$p")" "$spec"
    last=$((last + 1))
done
# Sort ahead of the distro build: 18.el10_3.alma.1 becomes 18.1.grdusbN.el10_3.alma.1.
release=$(rpmspec -q --srpm --qf '%{release}\n' "$spec" | head -1)
sed -i "s/^Release:.*/Release: ${release%%.*}.1.grdusb$REVISION%{?dist}/" "$spec"
# Lets grd-with-usb-redirect's packages require this build.
if [ -n "${PROVIDES:-}" ]; then
    sed -i "/^Release:/a Provides: $PROVIDES = %{version}-%{release}" "$spec"
fi
if [ -n "${RECOMMENDS:-}" ]; then
    sed -i "/^Release:/a Recommends: $RECOMMENDS" "$spec"
fi
dist=$(rpm --eval '%{dist}')
sed -i "/^%changelog/a * $(date '+%a %b %d %Y') $PACKAGER - ${VERSION%-*}-${release%%.*}.1.grdusb$REVISION\n- $CHANGES\n" "$spec"
dnf -y -q builddep "$spec" >/dev/null
rpmbuild -bs "$spec" >/dev/null
cp ~/rpmbuild/SRPMS/*.src.rpm /out/
if [ -n "$BINARY" ]; then
    rpmbuild -bb "$spec" > /out/"$SOURCE"-build.log 2>&1 || { tail -60 /out/"$SOURCE"-build.log; exit 1; }
    cp ~/rpmbuild/RPMS/*/*.rpm /out/
fi
SCRIPT
ls "$out"
