Name:           grd-with-usb-redirect
Version:        0.1.0
Release:        1%{?dist}
Summary:        GNOME remote desktop with USB redirection, for RDP gateways
License:        MIT OR Apache-2.0
URL:            https://github.com/wrouesnel/grd-with-usb-redirect
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch

BuildRequires:  systemd-rpm-macros

Requires:       rdp-usb-gw
Requires:       gnome-remote-desktop-urbdrc
Requires:       grd-headless-session = %{version}-%{release}
Recommends:     grd-no-lockscreen = %{version}-%{release}

%description
Installs everything for persistent headless GNOME desktops that RDP clients
reach directly, such as through an RDP gateway, with the client's USB devices
redirected to the desktop:
- rdp-usb-gw, the USB redirection daemon
- a gnome-remote-desktop build that lends rdp-usb-gw the session's USB
  redirection channel
- grd-headless-session, to start a user's session at boot
- grd-no-lockscreen, to turn off GNOME's lock screen

%package -n grd-headless-session
Summary:        Persistent headless GNOME sessions reachable over RDP
Requires:       gnome-remote-desktop
Requires:       gdm >= 1:47.0
Requires:       openssl
Requires:       shadow-utils
Requires:       systemd
Requires:       util-linux

%description -n grd-headless-session
grd-headless-session sets up a user's headless GNOME session to start at boot
and keep running when the RDP client disconnects, like a Windows Remote
Desktop session. RDP clients connect straight to it with gnome-remote-desktop,
without going through a login screen.

Each session gets a self-signed TLS certificate for the machine's name,
renewed when it nears expiry or the name changes.

%package -n grd-no-lockscreen
Summary:        Turn off GNOME's lock screen for remote sessions
Requires:       dconf

%description -n grd-no-lockscreen
Sets and locks GNOME's settings so sessions never lock. For desktops reached
through an RDP login, where the lock screen would be a second password
prompt, and in a headless session there is no console to unlock it from.

This applies to every user on the machine.

%prep
%autosetup

%build

%install
install -D -m 0755 headless-session/grd-headless-session %{buildroot}%{_sbindir}/grd-headless-session
install -D -m 0755 headless-session/grd-ensure-tls-cert %{buildroot}%{_libexecdir}/grd-with-usb-redirect/grd-ensure-tls-cert
install -D -m 0644 headless-session/gnome-remote-desktop-headless.service.d/50-grd-tls-cert.conf \
    %{buildroot}%{_userunitdir}/gnome-remote-desktop-headless.service.d/50-grd-tls-cert.conf
install -D -m 0644 no-lockscreen/50-grd-no-lockscreen %{buildroot}%{_sysconfdir}/dconf/db/local.d/50-grd-no-lockscreen
install -D -m 0644 no-lockscreen/50-grd-no-lockscreen.locks %{buildroot}%{_sysconfdir}/dconf/db/local.d/locks/50-grd-no-lockscreen

%post -n grd-no-lockscreen
dconf update || :

%postun -n grd-no-lockscreen
dconf update || :

%files
%license LICENSE-APACHE LICENSE-MIT
%doc README.md

%files -n grd-headless-session
%license LICENSE-APACHE LICENSE-MIT
%{_sbindir}/grd-headless-session
%{_libexecdir}/grd-with-usb-redirect/
%{_userunitdir}/gnome-remote-desktop-headless.service.d/50-grd-tls-cert.conf

%files -n grd-no-lockscreen
%license LICENSE-APACHE LICENSE-MIT
%config(noreplace) %{_sysconfdir}/dconf/db/local.d/50-grd-no-lockscreen
%config(noreplace) %{_sysconfdir}/dconf/db/local.d/locks/50-grd-no-lockscreen

%changelog
* Thu Nov 19 2026 Will Rouesnel <wrouesnel@wrouesnel.com> - 0.1.0-1
- First package.
