# a basic mostly-empty environment with /rpms added as an additional repo
FROM fedora
MAINTAINER https://github.com/rpm-software-management/dnf-plugin-system-upgrade

RUN dnf -y install dnf-command\(config-manager\)
RUN dnf config-manager testrpms --add-repo file:///rpms
