# grd-with-usb-redirect

Persistent headless GNOME desktops that RDP clients reach directly, such as through an RDP
gateway, with the client's USB devices redirected to the desktop. Connecting feels like
Remote Desktop to a Windows machine: the session is already running, it survives a
disconnect, it has a self-signed certificate for the machine's name, and a security key
plugged into the client works on the desktop.

This repository packages that for Ubuntu and Enterprise Linux. Each piece is a separate
package, so you can install only the parts you want.

| Package | What it does |
| --- | --- |
| `rdp-usb-gw` | The USB redirection daemon, from [rdp-usb-gw](https://github.com/wrouesnel/rdp-usb-gw). It works with any RDP server that has a proxy for it. |
| `gnome-remote-desktop` | The distribution's gnome-remote-desktop, rebuilt with a proxy for rdp-usb-gw and the fixes below. |
| `gdm3` (Ubuntu 24.04 only) | Ubuntu's gdm, rebuilt with `gdm-new-session` and `gnome-headless-session@.service`, backported from gdm 50. |
| `grd-headless-session` | Starts a user's headless session at boot, and gives it a TLS certificate. |
| `grd-no-lockscreen` | Turns off GNOME's lock screen for every user. |
| `grd-with-usb-redirect` | Installs all of the above. |

## Installing

**Ubuntu 24.04 and 26.04:**

```sh
sudo add-apt-repository ppa:w-rouesnel/grd-with-usb-redirect
sudo apt install grd-with-usb-redirect
```

**AlmaLinux, Rocky Linux and RHEL 10:**

```sh
sudo dnf copr enable wrouesnel/grd-with-usb-redirect
sudo dnf install grd-with-usb-redirect
```

USB redirection also needs the kernel's `vhci_hcd` module. Ubuntu ships it in
`linux-modules-extra-$(uname -r)`. EL10 kernels don't include it, but ELRepo's `kmod-usbip`
does.

## Setting up a desktop

As root, for each user who should have a remote desktop:

```sh
grd-headless-session enable --start alice
```

It reads the RDP password from stdin. The RDP username is the user's name. It:

- turns on lingering for the user, so their session can start at boot;
- adds them to the `rdp-usb-gw` group, if rdp-usb-gw is installed;
- gives their gnome-remote-desktop a self-signed TLS certificate for the machine's name;
- sets the RDP credentials and enables RDP, with full control rather than view-only;
- enables `gnome-remote-desktop-headless.service` for the user and
  `gnome-headless-session@alice.service`.

`--set-account-password` also makes the RDP password the account's password.
`grd-headless-session status alice` shows the session and gnome-remote-desktop's settings.
`grd-headless-session disable --stop alice` turns it off again.

Each user's gnome-remote-desktop listens on its own port. Set it with
`grdctl --headless rdp set-port` as the user. With an RDP gateway in front, the gateway
picks the desktop and port for each user.

**The certificate:** before gnome-remote-desktop starts, `grd-ensure-tls-cert` makes a new
certificate if there isn't one, if it expires within 30 days, or if the machine's name
changed. A certificate you configured yourself with `grdctl` is left alone.

**The lock screen:** `grd-no-lockscreen` sets and locks
`org.gnome.desktop.screensaver lock-enabled` to false and
`org.gnome.desktop.lockdown disable-lock-screen` to true, in dconf's `local` database. On
Ubuntu it also installs `/etc/dconf/profile/user`, which Ubuntu doesn't have, so that
database is read.

## What's changed in gnome-remote-desktop

| Change | 46 (Ubuntu 24.04) | 49 (EL10) | 50 (Ubuntu 26.04) | Upstream |
| --- | --- | --- | --- | --- |
| Proxy URBDRC channels to rdp-usb-gw | Ported | Added | Added | Not submitted yet |
| grdctl crashed reading credentials from a pipe | Fixed | Fixed | Fixed | Not submitted yet |
| grdctl reads credentials from stdin, not the command line | Backported from 47 | Already there | Already there | In 47 |
| A client stalling during the TLS handshake could hang the daemon | Socket shutdown backported | Already fixed by Red Hat | Backported | [MR 436](https://gitlab.gnome.org/GNOME/gnome-remote-desktop/-/merge_requests/436) |

## Layout

- `headless-session/` and `no-lockscreen/`: the files in `grd-headless-session` and
  `grd-no-lockscreen`.
- `debian/` and `packaging/rpm/grd-with-usb-redirect.spec`: packaging for those, and for
  the `grd-with-usb-redirect` package that pulls everything in.
- `packaging/<package>/<target>/`: the patches added to each distribution package, and how
  the package is rebuilt. `target.conf` names the distribution's version it's based on.
- `packaging/deb/rebuild.sh` and `packaging/rpm/rebuild-srpm.sh` rebuild a distribution
  package with those patches. `packaging/build-native.sh` builds this repository's own
  packages. Each runs in a container of the target distribution.

## License

The scripts and packaging are licensed under either of [Apache License 2.0](LICENSE-APACHE)
or [MIT](LICENSE-MIT), at your option. The patches to gnome-remote-desktop and gdm, like
those projects, are under the [GNU GPL, version 2 or later](COPYING), as are the packages
built from them.
