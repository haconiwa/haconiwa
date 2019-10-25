Name: haconiwa
Epoch: 1
Version: 0.11.0
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
* Fri Oct 25 2019 Uchio Kondo <udzura@udzura.jp> - 1:0.11.0-1
- rootfs default to ro in pivot_root mode. and add rootfs.readonly? opt

* Thu Oct 24 2019 Uchio Kondo <udzura@udzura.jp> - 1:0.10.10-1
- Fix and enhance readiness hook

* Thu Oct 17 2019 Uchio Kondo <udzura@udzura.jp> - 1:0.10.9-1
- Add readiness hooks

* Mon Oct  7 2019 Uchio Kondo <udzura@udzura.jp> - 1:0.10.8-1
- Refine probes, check NS before create network

* Fri Sep 27 2019 Uchio Kondo <udzura@udzura.jp> - 1:0.10.7-1
- Include USDTs for performence monitoring

* Tue Sep 24 2019 Uchio Kondo <udzura@udzura.jp> - 1:0.10.6-1
- Support action script, debug hook, hostname customization
