Name:           saldo
Version:        0.0.1
Release:        1%{?dist}
Summary:        Personal finances from Meu Pluggy: KDE app and Plasma widget

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
# The keyring is driven through secret-tool (shipped by libsecret).
Requires:       libsecret
# The Plasma widget (optional: the app works on its own).
Recommends:     plasma-workspace
Recommends:     kf6-kcmutils

%description
Saldo shows bank balances, credit card limits, card bills, investments and
transactions from the free Meu Pluggy personal-use API, as a Kirigami app and a
Plasma 6 widget. Credentials stay in the system keyring and data is cached
locally.

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
* Sat Nov 21 2026 Henrique Oliveira <henriik.dev@gmail.com> - 0.0.1-1
- Initial release.
