# This builds us an image containing a suitable build environment!
# To build, put the .spec and sources (tarballs etc.) in /src and run rpmbuild.
# RPMs will get written out to /rpms/<arch>/*.rpm.

FROM fedora
MAINTAINER https://github.com/rpm-software-management/dnf-plugin-system-upgrade

RUN dnf -y update && dnf -y install \
    @buildsys-build \
    rpmdevtools \
    createrepo

RUN useradd -Um rpm
RUN su --login rpm rpmdev-setuptree
RUN mkdir -p /rpms /src && \
    chown rpm.rpm /rpms /src && \
    echo '%_rpmdir /rpms' >> /home/rpm/.rpmmacros && \
    echo '%_sourcedir /src' >> /home/rpm/.rpmmacros

RUN dnf -y install gettext \
    pkgconfig \
    python-dnf \
    python-mock \
    python2-devel \
    python3-devel \
    python3-dnf \
    systemd \
    systemd-python \
    systemd-python3

VOLUME /rpms
USER rpm
CMD rpmbuild -bb /src/*.spec && createrepo /rpms
