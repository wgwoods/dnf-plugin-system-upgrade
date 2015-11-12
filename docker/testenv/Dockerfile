FROM fedora
MAINTAINER https://github.com/rpm-software-management/dnf-plugin-system-upgrade

RUN dnf -y update
RUN dnf -y install /rpms/*.rpm

ENTRYPOINT ["/usr/bin/dnf", "system-upgrade"]
