Name: haconiwa
Epoch: 1
Version: 0.8.4
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
%doc LICENSE LICENSE_argtable3 LICENSE_libcap LICENSE_libcgroup LICENSE_mruby README.md
%{_bindir}/*

%changelog
* Mon Apr 24 2017 Uchio Kondo <udzura@udzura.jp> - 1:0.8.4-1
- Support seccomp-bpf filter

* Fri Apr 21 2017 Uchio Kondo <udzura@udzura.jp> - 1:0.8.3-1
- Support haconiwa new hooks, including system hooks

* Thu Apr 13 2017 Uchio Kondo <udzura@udzura.jp> - 1:0.8.2-1
- Support haconiwa reload, implement thread watchdog

* Mon Apr  3 2017 Uchio Kondo <udzura@udzura.jp> - 1:0.8.1-1
- Remove experimental features. This destroys some of (minor) backward compatibilities

* Tue Mar 28 2017 Uchio Kondo <udzura@udzura.jp> - 1:0.8.0-1
- Bump mruby\'s version

* Thu Mar  2 2017 Uchio Kondo <udzura@udzura.jp> - 1:0.7.20170302-1
- Snapshot with cgroup warning fix
