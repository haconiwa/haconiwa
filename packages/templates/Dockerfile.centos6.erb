# -*- mode: dockerfile -*-
FROM centos:6.8
MAINTAINER Uchio Kondo <udzura@udzura.jp>

RUN yum -q -y update
RUN yum -q -y groupinstall "Development Tools"
RUN yum -q -y install \
    gcc gcc-c++ git openssl-devel zlib-devel \
    pam-devel readline-devel make \
    automake autoconf libtool rpm-build \
    glibc-headers glibc-static kernel-headers

RUN yum -y install epel-release
RUN yum -y install centos-release-SCL
RUN yum -y install ruby200 ruby200-rubygem-rake

RUN mkdir -p /root/rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
RUN sed -i "s;%_build_name_fmt.*;%_build_name_fmt\t%%{ARCH}/%%{NAME}-%%{VERSION}-%%{RELEASE}.el6.%%{ARCH}.rpm;" /usr/lib/rpm/macros

ENV VERSION <%= @latest %>
ENV USER root
ENV HOME /root
VOLUME /out

RUN mkdir -p /libexec
RUN echo '#!/bin/bash'                                        >  /libexec/buildrpm.sh
RUN echo 'set -xe'                                            >> /libexec/buildrpm.sh
RUN echo 'export PATH=$PATH:/opt/rh/ruby200/root/usr/bin'     >> /libexec/buildrpm.sh
RUN echo 'export LD_LIBRARY_PATH=/opt/rh/ruby200/root/usr/lib64' >> /libexec/buildrpm.sh
RUN echo 'git clone https://github.com/haconiwa/haconiwa.git /root/haconiwa-$VERSION' >> /libexec/buildrpm.sh
RUN echo 'cd /root'                                           >> /libexec/buildrpm.sh
RUN echo '( cd haconiwa-$VERSION; git checkout $(git rev-parse v$VERSION) )' >> /libexec/buildrpm.sh
RUN echo 'tar czf haconiwa-$VERSION.tar.gz haconiwa-$VERSION' >> /libexec/buildrpm.sh
RUN echo 'mv /root/haconiwa-$VERSION.tar.gz /root/rpmbuild/SOURCES'  >> /libexec/buildrpm.sh
RUN echo 'rpmbuild -bb haconiwa-$VERSION/packages/rpm/haconiwa.spec' >> /libexec/buildrpm.sh
RUN echo 'cp /root/rpmbuild/RPMS/*/*.rpm /out/pkg'            >> /libexec/buildrpm.sh
RUN chmod a+x /libexec/buildrpm.sh

CMD ["/libexec/buildrpm.sh"]
