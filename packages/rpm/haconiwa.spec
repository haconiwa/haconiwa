Name: haconiwa
Epoch: 1
Version: 0.2.2
Release: 1
Summary: MRuby on Container
License: GPLv3+
URL: https://github.com/haconiwa/haconiwa

BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-%(%{__id_u} -n)
BuildRequires: gcc gcc-c++ git openssl-devel zlib-devel pam-devel readline-devel rake make automake autoconf libtool
Requires: glibc
Requires(pre): shadow-utils

Source0: https://github.com/haconiwa/haconiwa/archive/master.tar.gz

%description
haconiwa - The MRuby on Container

%prep
%setup -q

%build
rake compile

%install
rake install prefix=%{buildroot}/usr

%clean
rake clean

%pre
if ! %{_bindir}/getent group haconiwa >/dev/null; then
    %{_sbindir}/addgroup --system --quiet haconiwa
fi
if ! %{_bindir}/getent passwd haconiwa >/dev/null; then
    %{_sbindir}/adduser --system --quiet --ingroup haconiwa haconiwa --home "/var/lib/haconiwa"
fi
%{_bindir}/mkdir -p /var/lib/haconiwa
%{_bindir}/chown haconiwa: /var/lib/haconiwa

%post

%preun

%postun

%files
%doc LICENSE README.md
%{_bindir}/*

%changelog
* Tue Jul 26 2016 Uchio Kondo <udzura@udzura.jp> - 1:0.2.2-1
- The initial release of rpm package
