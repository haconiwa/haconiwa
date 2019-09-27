Name: haconiwa
Epoch: 1
Version: 0.10.7
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
* Fri Sep 27 2019 Uchio Kondo <udzura@udzura.jp> - 1:0.10.7-1
- Include USDTs for performence monitoring

* Tue Sep 24 2019 Uchio Kondo <udzura@udzura.jp> - 1:0.10.6-1
- Support action script, debug hook, hostname customization

* Fri Sep 13 2019 Uchio Kondo <udzura@udzura.jp> - 1:0.10.5-1
- Change veth creation timing

* Sat Aug 10 2019 Uchio Kondo <udzura@udzura.jp> - 1:0.10.4-1
- Fix broken cleanup by fibered_worker change

* Thu Jun 20 2019 Uchio Kondo <udzura@udzura.jp> - 1:0.10.3-1
- Add cgroup.name DSL, change mruby target to 2.0.1

* Tue Feb 19 2019 Uchio Kondo <udzura@udzura.jp> - 1:0.10.2-1
- Support leave-running option for dump
