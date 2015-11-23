#!/bin/bash

RESULTFILE=/testenv/RESULT

runcmd() {
    echo ">>> $@"
    "$@"
}

fail() {
    echo "FAIL: $*" > $RESULTFILE
    copy_logs
    exit 1
}

copy_logs() {
    cp /var/log/dnf.log /testenv/dnf.log
    # FIXME: how does the journal even work in a container anyway
    #journalctl -b > /testenv/upgrade.log
}

# Parse commandline variables
RPM_NAME="$1"
TARGET_RELEASEVER="$2"

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

# Run the upgrade (like the service does)
runcmd dnf --releasever=${RELEASEVER} system-upgrade upgrade --no-reboot || \
    fail "upgrade failed"

# Exit successfully!
echo "PASS" > $RESULTFILE
copy_logs
exit 0
