# This builds us some new RPMs and stuffs them into the /rpms volume
FROM fedora
MAINTAINER https://github.com/rpm-software-management/dnf-plugin-system-upgrade

RUN dnf -y update && dnf -y install \
    @buildsys-build \
    dnf-command\(builddep\) \
    rpmdevtools \
    createrepo

RUN useradd -Um rpm
RUN su --login rpm rpmdev-setuptree
WORKDIR /home/rpm/rpmbuild

COPY *.spec /src/
RUN dnf -y builddep --spec /src/*.spec

COPY *.tar.gz SOURCES/
RUN su --login rpm -c 'rpmbuild -bb /src/*.spec' && \
    mkdir /rpms && mv -v RPMS/*/*.rpm /rpms && createrepo /rpms
VOLUME /rpms
