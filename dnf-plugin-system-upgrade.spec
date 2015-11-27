Name:       dnf-plugin-system-upgrade
Version:    0.7.1
Release:    1%{?dist}
Summary:    System Upgrade plugin for DNF
Group:      System Environment/Base
License:    GPLv2+
URL:        https://github.com/rpm-software-management/dnf-plugin-system-upgrade
Source0:    https://github.com/rpm-software-management/dnf-plugin-system-upgrade/archive/%{version}.tar.gz#/%{name}-%{version}.tar.gz

%if 0%{?fedora} >= 23
# DNF in Fedora 23 uses Python 3 by default
Requires: python3-%{name} = %{version}-%{release}
%else
Requires: python2-%{name} = %{version}-%{release}
%endif

Provides: dnf-command(system-upgrade)

# The plugin itself doesn't technically require dnf, but /usr/bin/fedup does.
# So either we split out a subpackage for /usr/bin/fedup or we Require dnf.
Requires: dnf

# This replaces the old fedup package..
Provides: fedup = 0.9.3-1
Obsoletes: fedup < 0.9.3-1
# ..just for cleanliness, obsolete fedup-dracut too. (#1275085)
Obsoletes: fedup-dracut

Conflicts: PackageKit < 1.0.8

# distro-sync upgrade doesn't work with old libsolv and hawkey. See
# https://bugzilla.redhat.com/show_bug.cgi?id=1260989
Requires: libsolv >= 0.6.14-2
Requires: hawkey >= 0.6.2-1

BuildArch: noarch
BuildRequires: pkgconfig systemd gettext

%description
System Upgrade plugin for DNF.
This package provides the systemd services required to make the upgrade work.

%package -n python3-%{name}
%{?python_provide:%python_provide python3-%{name}}
Summary:    System Upgrade plugin for DNF
Requires:   python3-dnf >= 1.1.4
Requires:   systemd-python3
BuildRequires:  python3-devel python3-dnf systemd-python3
%description -n python3-%{name}
System Upgrade plugin for DNF (Python 3 version).
This package provides the "system-upgrade" command.

%package -n python2-%{name}
%{?python_provide:%python_provide python2-%{name}}
Summary:    System Upgrade plugin for DNF
# TODO: change to 'python2-dnf' once that exists
Requires:   python-dnf >= 1.1.4
Requires:   systemd-python
BuildRequires: python2-devel python-mock python-dnf systemd-python
%description -n python2-%{name}
System Upgrade plugin for DNF (Python 2 version).
This package provides the "system-upgrade" command.

%prep
%setup -q -n %{name}-%{version}

%build
make %{?_smp_mflags}

%install
make install DESTDIR=$RPM_BUILD_ROOT PYTHON=%{__python2}
%find_lang %{name}
make install-plugin DESTDIR=$RPM_BUILD_ROOT PYTHON=%{__python3}

%check
make check PYTHON=%{__python2} LANG=de_DE.UTF-8
make check PYTHON=%{__python3}

%pre
# if we're replacing fedup, we need to make sure it cleans up its leftovers.
# (see https://bugzilla.redhat.com/show_bug.cgi?id=1264948)
if [ "$1" == 1 -a -x /usr/bin/fedup ]; then
    # save the old package cache (if the new one isn't populated)
    if [ -d /var/lib/system-upgrade ]; then
        mv -f -T /var/lib/system-upgrade /var/lib/dnf/system-upgrade || :
    fi
    # clean up everything else
    /usr/bin/fedup --clean || :
fi

%files -f %{name}.lang
%license LICENSE
%doc README.md
%{_mandir}/man8/dnf.plugin.system-upgrade.8*
%{_mandir}/man8/fedup.8*
%{_unitdir}/dnf-system-upgrade.service
%dir %{_unitdir}/system-update.target.wants
%{_unitdir}/system-update.target.wants/dnf-system-upgrade.service
%{_bindir}/fedup

%files -n python3-%{name}
%license LICENSE
%{python3_sitelib}/dnf-plugins/system_upgrade.py
%{python3_sitelib}/dnf-plugins/__pycache__/system_upgrade*.py*

%files -n python2-%{name}
%license LICENSE
%{python_sitelib}/dnf-plugins/system_upgrade.py*

%changelog
* Wed Nov 11 2015 Will Woods <wwoods@redhat.com> 0.7.1-1
- Fix crash at startup with zh_CN and other utf8 locales (#1278031, #1277895)
- Fix upgrades using `-x` or `--exclude`

* Tue Oct 27 2015 Will Woods <wwoods@redhat.com> 0.7.0-1
- Add `log` subcommand (to show upgrade logs)
- Fix upgrades on systems without `plymouth` installed
- Fix upgrades using `--best` or `--allowerasing` (#1266589)
- Drop compatibility with DNF < 1.1.0; bump version number to avoid confusion.
- Clean up stuff left behind by the old fedup package (#1264948)

* Tue Sep 15 2015 Will Woods <wwoods@redhat.com> 0.4.1-1
- Fix `dnf system-upgrade clean` (rhbz#1262145)
- Fix duplicate messages in plymouth 'details' output (github#13)
- Add man pages dnf.plugin.system-upgrade(8) and fedup(8)

* Wed Sep 09 2015 Kalev Lember <klember@redhat.com> 0.4.0-2
- Conflict with older PackageKit versions that didn't let other programs do
  offline updates (#1259937)
- Pull in the Python 3 version of the DNF plugin on Fedora 23 (#1260164)

* Mon Aug 31 2015 Will Woods <wwoods@redhat.com> 0.4.0-1
- Meet Fedora packaging requirements
- Add translations to `fedup` wrapper

* Thu Aug 20 2015 Will Woods <wwoods@redhat.com> 0.3.0-1
- Add `fedup` backward-compatibility wrapper

* Tue Aug 18 2015 Will Woods <wwoods@redhat.com> 0.2.0-1
- Fix upgrade startup

* Wed Aug 05 2015 Will Woods <wwoods@redhat.com> 0.0.1-1
- Initial packaging
