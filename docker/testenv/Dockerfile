# A basic test environment.
# DNF is configured to use a repo at /rpms (e.g. from a rpmbuild container)

FROM fedora
MAINTAINER https://github.com/rpm-software-management/dnf-plugin-system-upgrade

RUN dnf -y install kernel dnf-command\(config-manager\)
RUN dnf config-manager testrpms --add-repo file:///rpms
