# A basic test environment.
# DNF is configured to use a repo at /rpms (e.g. from a rpmbuild container)

FROM fedora:21
MAINTAINER https://github.com/rpm-software-management/dnf-plugin-system-upgrade

RUN yum -y install dnf
RUN dnf -y install kernel dnf-plugins-core
RUN dnf config-manager testrpms --add-repo file:///rpms
