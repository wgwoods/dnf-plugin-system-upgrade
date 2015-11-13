FROM fedora
MAINTAINER https://github.com/rpm-software-management/dnf-plugin-system-upgrade

RUN dnf -y update && dnf -y install \
    @buildsys-build \
    dnf-command\(builddep\) \
    rpmdevtools \
    createrepo

COPY *.spec /src/
RUN dnf -y builddep --spec /src/*.spec

RUN useradd -Um rpm
RUN mkdir /rpms && chown rpm.rpm /rpms
USER rpm
RUN rpmdev-setuptree
WORKDIR /home/rpm/rpmbuild

COPY *.tar.gz SOURCES/
RUN rpmbuild -bb /src/*.spec && mv RPMS/*/*.rpm /rpms && createrepo /rpms
VOLUME /rpms
