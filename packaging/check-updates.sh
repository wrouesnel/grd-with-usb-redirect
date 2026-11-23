#!/usr/bin/env bash
# Compares the distribution version each rebuild is based on (VERSION in
# packaging/<package>/<target>/target.conf) with the distribution's latest, so
# an update that would replace the patched build isn't missed.
#
# Usage: packaging/check-updates.sh
# Exits 1 if any rebuild is behind.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
behind=0

latest_ubuntu() {  # <source> <series>
    curl -fsS "https://api.launchpad.net/1.0/ubuntu/+archive/primary?ws.op=getPublishedSources&source_name=$1&exact_match=true&status=Published&distro_series=https://api.launchpad.net/1.0/ubuntu/$2" |
        python3 -c 'import json, sys
# Skip -proposed: it is not enabled by default, so it has not reached users.
versions = [e["source_package_version"] for e in json.load(sys.stdin)["entries"]
            if e["pocket"] != "Proposed"]
print("\n".join(versions))' |
        sort -V | tail -1
}

latest_el10() {  # <package>
    podman run --rm docker.io/library/almalinux:10 \
        dnf -q repoquery --latest-limit 1 --qf 'version=%{version}-%{release}\n' "$1" 2>&1 |
        sed -n 's/^version=//p' | tail -1
}

for conf in "$here"/*/*/target.conf; do
    target=$(basename "$(dirname "$conf")")
    VERSION= SOURCE=
    # shellcheck source=/dev/null
    . "$conf"
    case $target in
        el10) latest=$(latest_el10 "$SOURCE") ;;
        *) latest=$(latest_ubuntu "$SOURCE" "$target") ;;
    esac
    if [ -z "$latest" ]; then
        echo "?  $SOURCE $target: couldn't find the latest version"
    elif [ "$latest" = "$VERSION" ]; then
        echo "ok $SOURCE $target: $VERSION"
    else
        echo "!! $SOURCE $target: based on $VERSION, latest is $latest"
        behind=1
    fi
done
exit $behind
