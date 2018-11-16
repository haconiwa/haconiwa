Name: haconiwa
Epoch: 1
Version: 0.10.0~alpha5
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
* Fri Nov 16 2018 Uchio Kondo <udzura@udzura.jp> - 1:0.10.0~alpha5-1
- Alpha release of criu-included one

* Wed Oct 24 2018 Uchio Kondo <udzura@udzura.jp> - 1:0.9.5-1
- Fix blocking in evaluating a hacofile including some literals

* Fri Oct 12 2018 Uchio Kondo <udzura@udzura.jp> - 1:0.9.4-1
- Backport some of 0.10 features

* Thu Oct  4 2018 Uchio Kondo <udzura@udzura.jp> - 1:0.9.3-1
- Support masking of sensitive files and dirs

* Wed Aug  8 2018 Uchio Kondo <udzura@udzura.jp> - 1:0.9.2-1
- Upgrade mruby version

* Mon Apr 16 2018 Uchio Kondo <udzura@udzura.jp> - 1:0.9.1-1
- Apply some enhancements to reduce memory consumption
