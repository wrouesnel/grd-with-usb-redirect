#!/bin/sh
# Runs in the unpacked source, after the patches are added.
set -eu
# The patches link the daemon against polkit.
sed -i 's/^Build-Depends: /Build-Depends: libpolkit-gobject-1-dev,\n               /' debian/control
# Lets packages that need gdm-new-session depend on this build rather than on
# a version number, so an archive update that lacks it is held back.
sed -i '/^Package: gdm3$/,/^$/s/^Provides: x-display-manager$/Provides: gdm-new-session, x-display-manager/' debian/control
grep -q 'Provides: gdm-new-session' debian/control
# The polkit action and rule for CreateUserDisplay, which the patches install.
printf '%s\n' usr/share/polkit-1/actions/org.gnome.displaymanager.policy \
    usr/share/polkit-1/rules.d/20-gdm.rules >> debian/gdm3.install
# libgdm1 exports the helper that patch 0001 adds to the common code.
sed -i 's/^\( gdm_find_display_session@Base .*\)$/\1\n gdm_find_graphical_sessions_for_username@Base 46.2-1ubuntu1~24.04.9+grdusb1/' debian/libgdm1.symbols
grep -q gdm_find_graphical_sessions_for_username debian/libgdm1.symbols
