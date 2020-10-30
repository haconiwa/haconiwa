Name: haconiwa
Epoch: 1
Version: 0.11.5
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
* Fri Oct 30 2020 Uchio Kondo <udzura@udzura.jp> - 1:0.11.5-1
- Important: Fix blocking SIGCHLD after container is created

* Thu Oct 29 2020 Uchio Kondo <udzura@udzura.jp> - 1:0.11.4-1
- Block SIGCHLD in early container setup phase to avoid defunct

* Tue Jan 28 2020 Uchio Kondo <udzura@udzura.jp> - 1:0.11.3-1
- Add loop limit and current_timer

* Fri Dec 13 2019 Uchio Kondo <udzura@udzura.jp> - 1:0.11.2-1
- Reduce CPU usage on busyloop

* Wed Nov 20 2019 Uchio Kondo <udzura@udzura.jp> - 1:0.11.1-1
- Add option to just assign cgroup v2, apply eval issue patch

* Fri Oct 25 2019 Uchio Kondo <udzura@udzura.jp> - 1:0.11.0-1
- rootfs default to ro in pivot_root mode. and add rootfs.readonly? opt
