# -*- mode: dockerfile -*-
FROM centos:7.4.1708
MAINTAINER Uchio Kondo <udzura@udzura.jp>

RUN yum -q -y update
RUN yum -q -y groupinstall "Development Tools"
RUN yum -q -y install \
    gcc gcc-c++ git openssl-devel zlib-devel \
    pam-devel readline-devel rake make \
    automake autoconf libtool rpm-build \
    glibc-headers glibc-static
RUN yum -q -y install \
    protobuf protobuf-c protobuf-c-devel \
    protobuf-compiler protobuf-devel protobuf-python \
    pkg-config libcap-devel libnet-devel libnl3-devel \
    perl-Pod-Checker

RUN mkdir -p /root/rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
RUN sed -i "s;%_build_name_fmt.*;%_build_name_fmt\t%%{ARCH}/%%{NAME}-%%{VERSION}-%%{RELEASE}.el7.%%{ARCH}.rpm;" /usr/lib/rpm/macros

ENV VERSION <%= @latest %>
ENV USER root
ENV HOME /root
VOLUME /out

RUN mkdir -p /libexec
RUN echo '#!/bin/bash'                                        >  /libexec/buildrpm.sh
RUN echo 'set -xe'                                            >> /libexec/buildrpm.sh
RUN echo 'git clone https://github.com/haconiwa/haconiwa.git /root/haconiwa-$VERSION' >> /libexec/buildrpm.sh
RUN echo 'cd /root'                                           >> /libexec/buildrpm.sh
RUN echo 'cd haconiwa-$VERSION; git checkout $(git rev-parse v$VERSION)' >> /libexec/buildrpm.sh
RUN echo 'sed -i.bak "1iENV[%(CRIU_TMP_DIR)] = %(/tmp/criu-build)" build_config.rb' >> /libexec/buildrpm.sh
RUN echo 'sed -i.bak "5iconf.cc.defines << %(MRB_CRIU_USE_STATIC)" build_config.rb' >> /libexec/buildrpm.sh
RUN echo 'cd ../'                                             >> /libexec/buildrpm.sh
RUN echo 'tar czf haconiwa-$VERSION.tar.gz haconiwa-$VERSION' >> /libexec/buildrpm.sh
RUN echo 'mv /root/haconiwa-$VERSION.tar.gz /root/rpmbuild/SOURCES'  >> /libexec/buildrpm.sh
RUN echo 'rpmbuild -bb haconiwa-$VERSION/packages/rpm/haconiwa.spec' >> /libexec/buildrpm.sh
RUN echo 'cp /root/rpmbuild/RPMS/*/*.rpm /out/pkg'            >> /libexec/buildrpm.sh
RUN chmod a+x /libexec/buildrpm.sh

CMD ["/libexec/buildrpm.sh"]
