Name: haconiwa
Epoch: 1
Version: 0.5.2
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
%{__mkdir_p} /var/lib/haconiwa
%{__chown} haconiwa: /var/lib/haconiwa

%post

%preun

%postun

%files
%doc LICENSE LICENSE_argtable3 LICENSE_libcap LICENSE_libcgroup LICENSE_mruby LICENSE_libuv README.md
%{_bindir}/*

%changelog
* Wed Dec 21 2016 Uchio Kondo <udzura@udzura.jp> - 1:0.5.2-1
- Add command.set_stdin/stdout/stderr, and workdir

* Fri Dec  9 2016 Uchio Kondo <udzura@udzura.jp> - 1:0.5.1-1
- Fix that cannot define signal handlers for supervisor

* Wed Nov 30 2016 Uchio Kondo <udzura@udzura.jp> - 1:0.5.0-1
- Add after_spawn hook, intoduce default caps, persistant namespace

* Wed Nov 16 2016 Uchio Kondo <udzura@udzura.jp> - 1:0.4.6-1
- Small fixes in uid mapped attach, support archive subcommand

* Mon Nov 14 2016 Uchio Kondo <udzura@udzura.jp> - 1:0.4.5-1
- Fix brken option haconiwa attach -t, support centos 6 attach

* Fri Nov 11 2016 Uchio Kondo <udzura@udzura.jp> - 1:0.4.4-1
- Fix failing to drop caps when g/uid mappping is active
