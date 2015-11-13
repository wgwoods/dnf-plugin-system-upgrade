FROM fedora
MAINTAINER https://github.com/rpm-software-management/dnf-plugin-system-upgrade

RUN dnf -y install dnf-command\(config-manager\)

COPY ./rpms /rpms
RUN dnf config-manager testrpms --add-repo file:///rpms
CMD /bin/bash
