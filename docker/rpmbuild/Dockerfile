FROM fedora
MAINTAINER https://github.com/rpm-software-management/dnf-plugin-system-upgrade

RUN dnf -y update && dnf -y install \
    @buildsys-build \
    dnf-command\(builddep\) \
    rpmdevtools

COPY *.spec /src/
RUN dnf -y builddep --spec /src/*.spec

RUN useradd -Um rpm
RUN mkdir /rpms && chown rpm.rpm /rpms
USER rpm
RUN rpmdev-setuptree

COPY *.tar.gz /home/rpm/rpmbuild/SOURCES/
RUN rpmbuild -bb /src/*.spec && cp -av /home/rpm/rpmbuild/RPMS/*/*.rpm /rpms
VOLUME /rpms
