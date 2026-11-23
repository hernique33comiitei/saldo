Name:           saldo
Version:        0.0.4
Release:        1%{?dist}
Summary:        Personal finances from Open Finance (Meu Pluggy): KDE app and Plasma widget

License:        MIT
URL:            https://github.com/hernique33comiitei/saldo
Source0:        %{url}/archive/v%{version}/%{name}-%{version}.tar.gz

BuildRequires:  cmake
BuildRequires:  ninja-build
BuildRequires:  gcc-c++
BuildRequires:  extra-cmake-modules
BuildRequires:  gettext
BuildRequires:  desktop-file-utils
BuildRequires:  appstream
BuildRequires:  qt6-qtbase-devel
BuildRequires:  qt6-qtdeclarative-devel
BuildRequires:  kf6-kirigami-devel
BuildRequires:  kf6-ki18n-devel
BuildRequires:  kf6-kcoreaddons-devel

# Runtime libraries (Qt6/KF6) are picked up automatically from the ELF, but the
# QML modules and image plugins are dlopened, so require them explicitly.
Requires:       qt6-qtdeclarative
Requires:       qt6-qtsvg
Requires:       kf6-kirigami
Requires:       kf6-ki18n
Requires:       kf6-kcoreaddons
Requires:       kf6-kquickcharts
# KDE look outside Plasma (GNOME etc.): the org.kde.desktop Qt Quick style and
# the Breeze icons the UI uses. Plasma brings both; nothing else does.
Requires:       kf6-qqc2-desktop-style
Requires:       breeze-icon-theme
# The keyring is driven through secret-tool (shipped by libsecret).
Requires:       libsecret
# The Plasma widget (optional: the app works on its own).
Recommends:     plasma-workspace
Recommends:     kf6-kcmutils

%description
Saldo shows bank balances, credit card limits, card bills, investments and
transactions from Open Finance Brasil, through the free Meu Pluggy personal-use
API, as a Kirigami app and a Plasma 6 widget. Brazilian banks only. Credentials
stay in the system keyring and data is cached locally.

%prep
%autosetup -n %{name}-%{version}

%build
%cmake -GNinja
%cmake_build

%install
%cmake_install
%find_lang saldo

%check
desktop-file-validate %{buildroot}%{_datadir}/applications/io.github.hernique33comiitei.Saldo.desktop
appstreamcli validate --no-net %{buildroot}%{_metainfodir}/io.github.hernique33comiitei.Saldo.metainfo.xml || :
export QT_QPA_PLATFORM=offscreen
%ctest

%files -f saldo.lang
%license LICENSE
%doc README.md
%{_bindir}/saldo
%{_libdir}/libsaldocore.so.0
%{_libdir}/libsaldocore.so.%{version}
%{_qt6_qmldir}/org/saldo/
%{_datadir}/plasma/plasmoids/io.github.hernique33comiitei.saldo/
%{_datadir}/applications/io.github.hernique33comiitei.Saldo.desktop
%{_metainfodir}/io.github.hernique33comiitei.Saldo.metainfo.xml
%{_datadir}/icons/hicolor/scalable/apps/saldo.svg
%{_datadir}/icons/hicolor/scalable/apps/saldo-symbolic.svg

%changelog
* Mon Nov 23 2026 Henrique Oliveira <henriik.dev@gmail.com> - 0.0.4-1
- Works on desktops without KDE Plasma, such as GNOME: the packages now bring the KDE style and the Breeze icons the app needs
- The app opens even when the KDE style is missing, with Qt's default look

* Mon Nov 23 2026 Henrique Oliveira <henriik.dev@gmail.com> - 0.0.3-1
- The overview footer shows the latest Pluggy update and the next one to come, even when one bank is late
- Clearer warning when Pluggy has not updated a bank for two days

* Mon Nov 23 2026 Henrique Oliveira <henriik.dev@gmail.com> - 0.0.2-1
- Choose the app language in Settings: system default, English or Português (Brasil)
- Portuguese description in the software center, saying the data comes from Open Finance Brasil
- Fixed the demo showing each example connection twice

* Mon Nov 23 2026 Henrique Oliveira <henriik.dev@gmail.com> - 0.0.1-1
- Bank balances, credit card limits, bills, investments and transactions from the free Meu Pluggy personal-use API
- Overview with next card bills, credit limit, spending by category, income and expenses and balance history, by month
- Card details with the open bill, the last closed bill and whether it was paid
- Transfers between your own accounts and card bill payments are not counted as income or expenses
- Plasma 6 widget for the panel or the system tray
- Step-by-step guide to connect Meu Pluggy; credentials stay in the system keyring

