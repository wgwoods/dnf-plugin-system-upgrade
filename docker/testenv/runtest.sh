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

error() {
    echo "ERROR: $*" | tee $RESULTFILE
    exit 2
}

copy_logs() {
    cp -a /var/log/dnf.log $RESULTDIR/
    # FIXME: how does the journal even work in a container anyway
    #journalctl -b > $RESULTDIR/upgrade.log
}

# Grab $releasever and set TARGET_RELEASEVER if not already set
RELEASEVER=$(source /etc/os-release; echo $VERSION_ID)
[ -n "$TARGET_RELEASEVER" ] || TARGET_RELEASEVER=$(($RELEASEVER+1))

# Check for required environment variables
[ -n "$RPM_NAME" ] || error "RPM_NAME not set"
[ -n "$TARGET_RELEASEVER" ] || error "TARGET_RELEASEVER not set"

# okay, we're ready to begin
echo "=== $RPM_NAME: test upgrade to F$TARGET_RELEASEVER"

runcmd find /rpms -name "*.rpm" | grep -q "$RPM_NAME" || \
    fail "$RPM_NAME not found in container"

# Install the plugin. Note optional INSTALL_ARGS env variable here.
runcmd dnf -y --nogpgcheck $INSTALL_ARGS install "$RPM_NAME" || \
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
