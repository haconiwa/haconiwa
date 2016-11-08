Name: haconiwa
Epoch: 1
Version: 0.4.1
Release: 1
Summary: MRuby on Container
License: GPLv3+
URL: https://github.com/haconiwa/haconiwa

BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-%(%{__id_u} -n)
BuildRequires: gcc gcc-c++ git openssl-devel zlib-devel pam-devel readline-devel rubygem-rake make automake autoconf libtool
Requires: glibc
Requires(pre): shadow-utils

Source0: haconiwa-%{version}.tar.gz

%description
haconiwa - The MRuby on Container

%prep
%setup -q

%build
rake compile_all

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
%{_bindir}/mkdir -p /var/lib/haconiwa
%{_bindir}/chown haconiwa: /var/lib/haconiwa

%post

%preun

%postun

%files
%doc LICENSE LICENSE_argtable3 LICENSE_libcap LICENSE_libcgroup LICENSE_mruby LICENSE_libuv README.md
%{_bindir}/*

%changelog
* Mon Sep  5 2016 Uchio Kondo <udzura@udzura.jp> - 1:0.4.1-1
- Experimental support for uid/gid mapping, note that some feature might be broken

* Tue Aug 30 2016 Uchio Kondo <udzura@udzura.jp> - 1:0.4.0-1
- Experimental support haconiwa watch, bump mruby, fix some bugs

* Mon Aug 29 2016 Uchio Kondo <udzura@udzura.jp> - 1:0.3.5-1
- Add network etc sharing options

* Fri Aug 26 2016 Uchio Kondo <udzura@udzura.jp> - 1:0.3.4-1
- Support ENV in DSL, fix some bug on run

* Wed Aug 24 2016 Uchio Kondo <udzura@udzura.jp> - 1:0.3.3-1
- Enhance ps subcommand with one more fix

* Tue Aug 23 2016 Uchio Kondo <udzura@udzura.jp> - 1:0.3.3-1
- Fix some haconiwa ps troubles

* Tue Aug 23 2016 Uchio Kondo <udzura@udzura.jp> - 1:0.3.1-1
- Support haconiwa ps, cooperating with etcd

* Fri Aug 19 2016 Uchio Kondo <udzura@udzura.jp> - 1:0.3.0-1
- Support new subcommand to generate DSL boilerplate
- Support entering existing namespace(useful with netns)
- Add mount_independent, deprecate mount_independent_procfs

* Fri Aug  5 2016 Uchio Kondo <udzura@udzura.jp> - 1:0.2.4-1
- Support create/provision subcommand

* Tue Jul 26 2016 Uchio Kondo <udzura@udzura.jp> - 1:0.2.3-1
- Update licenses

* Fri Jul 22 2016 Uchio Kondo <udzura@udzura.jp> - 1:0.2.2-1
- Initial release of haconiwa package
