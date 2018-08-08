Name: haconiwa
Epoch: 1
Version: 0.9.2
Release: 1
Summary: MRuby on Container
License: GPLv3+
URL: https://github.com/haconiwa/haconiwa

BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-%(%{__id_u} -n)
BuildRequires: gcc gcc-c++ git openssl-devel zlib-devel pam-devel readline-devel make automake autoconf libtool
Requires: glibc
Requires(pre): shadow-utils

Source0: haconiwa-%{version}.tar.gz

%description
haconiwa - The MRuby on Container

%prep
%setup -q

%build
rake all

%install
rake install prefix=%{buildroot}/usr

%clean
rake clean

%pre
if ! %{_bindir}/getent group haconiwa >/dev/null; then
    %{_sbindir}/groupadd --system haconiwa
fi
if ! %{_bindir}/getent passwd haconiwa >/dev/null; then
    %{_sbindir}/useradd --system --gid haconiwa --home-dir "/var/lib/haconiwa" haconiwa
fi
%{__mkdir_p} /var/lib/haconiwa
%{__chown} haconiwa: /var/lib/haconiwa

%post

%preun

%postun

%files
%doc LICENSE LICENSE_argtable3 LICENSE_libcap LICENSE_libcgroup LICENSE_mruby README.md
%{_bindir}/*

%changelog
* Wed Aug  8 2018 Uchio Kondo <udzura@udzura.jp> - 1:0.9.2-1
- Upgrade mruby version

* Mon Apr 16 2018 Uchio Kondo <udzura@udzura.jp> - 1:0.9.1-1
- Apply some enhancements to reduce memory consumption

* Thu Apr 12 2018 Uchio Kondo <udzura@udzura.jp> - 1:0.9.0-1
- Change mruby version to current master, drop dependencies to mruby-thread

* Wed Dec 20 2017 Uchio Kondo <udzura@udzura.jp> - 1:0.8.9-1
- Support network configuration DSL

* Tue Dec  5 2017 Uchio Kondo <udzura@udzura.jp> - 1:0.8.8-1
- Support lxcfs API endpoint

* Tue Jun 27 2017 Uchio Kondo <udzura@udzura.jp> - 1:0.8.7-1
- Support metadata / Prevent doubel startup - and now pid file contains supervisor pid
