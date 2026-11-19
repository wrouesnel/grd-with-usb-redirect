#!/usr/bin/env bash
# Signs and uploads source packages to the PPA, or source RPMs to COPR.
#
# Usage:
#   packaging/publish.sh ppa <file>_source.changes...
#   packaging/publish.sh copr <file>.src.rpm...
#
# Signing uses the Launchpad key; its passphrase is read from the keyring and
# passed to gpg on a file descriptor. COPR uses the copr-cli config in the
# keyring. Neither is ever on a command line or on disk.
set -euo pipefail
PPA=ppa:w-rouesnel/grd-with-usb-redirect
COPR=wrouesnel/grd-with-usb-redirect
KEY=${SIGNING_KEY:-2A128435A6FE8BD751AA578720959AB807096ADB}
# debsign and copr-cli, where they aren't installed.
DEBSIGN=${DEBSIGN:-$(command -v debsign || echo ~/.cache/grd-usb/tools/devscripts/usr/bin/debsign)}
COPR_CLI=${COPR_CLI:-$(command -v copr-cli || echo ~/.cache/grd-usb/tools/copr-venv/bin/copr-cli)}

what=$1; shift
case $what in
ppa)
    for changes in "$@"; do
        "$DEBSIGN" -k"$KEY" -p"gpg --pinentry-mode loopback --passphrase-fd 3" "$changes" \
            3< <(secret-tool lookup service gpg-passphrase fingerprint "$KEY")
        dput "$PPA" "$changes"
    done
    ;;
copr)
    for srpm in "$@"; do
        "$COPR_CLI" --config <(secret-tool lookup service copr-cli host copr.fedorainfracloud.org) \
            build --nowait "$COPR" "$srpm"
    done
    ;;
*) echo "usage: $0 ppa|copr files..." >&2; exit 2 ;;
esac
