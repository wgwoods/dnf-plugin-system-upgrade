#!/bin/bash

RESULTDIR=/results
RESULTFILE=$RESULTDIR/RESULT

runcmd() {
    echo ">>> $@"
    "$@"
}

fail() {
    echo "FAIL: $*" | tee $RESULTFILE
    copy_logs
    exit 1
}

copy_logs() {
    cp -a /var/log/dnf.log $RESULTDIR/
    # FIXME: how does the journal even work in a container anyway
    #journalctl -b > $RESULTDIR/upgrade.log
}

# Parse commandline variables
RPM_NAME="$1"
TARGET_RELEASEVER="$2"

runcmd find /rpms -name "*.rpm" | grep -q "$RPM_NAME" || \
    fail "$RPM_NAME not found in container"

# Install the plugin
runcmd dnf -y --nogpgcheck install "$RPM_NAME" || \
    fail "could not install $RPM_NAME"

# Download packages for upgrade
runcmd dnf -y system-upgrade download --releasever=$TARGET_RELEASEVER || \
    fail "download returned $?"

# Prepare system for upgrade
runcmd dnf -y system-upgrade reboot --no-reboot || \
    fail "reboot returned $?"

# Load the flag file (like the service does)
source /system-update/.dnf-system-upgrade || \
    fail "flag file missing or malformed"

# Run the upgrade (like the service does, but without rebooting)
runcmd dnf --releasever=${RELEASEVER} system-upgrade upgrade --no-reboot || \
    fail "upgrade failed"

# Exit successfully!
echo "PASS" | tee $RESULTFILE
copy_logs
exit 0
