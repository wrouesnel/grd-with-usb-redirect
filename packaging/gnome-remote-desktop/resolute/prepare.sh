#!/bin/sh
# Runs in the unpacked source, after the patches are added.
set -eu
# The Provides let grd-with-usb-redirect's packages depend on this build rather
# than on a version number, so an archive update without the patches is held
# back.
awk '
  function finish() {
    if (in_pkg) {
      print "Provides: gnome-remote-desktop-urbdrc"
      if (!has_rec) print "Recommends: rdp-usb-gw"
    }
    in_pkg = 0
  }
  /^Package: / { finish() }
  /^Package: gnome-remote-desktop$/ { in_pkg = 1 }
  in_pkg && /^Recommends: / { sub(/^Recommends: /, "Recommends: rdp-usb-gw, "); has_rec = 1 }
  in_pkg && /^Provides: / { print "unexpected Provides" > "/dev/stderr"; exit 1 }
  /^$/ { finish() }
  { print }
  END { finish() }
' debian/control > debian/control.new
mv debian/control.new debian/control
grep -q '^Provides: gnome-remote-desktop-urbdrc' debian/control
