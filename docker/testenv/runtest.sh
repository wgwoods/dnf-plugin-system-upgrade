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

check_cache() {
    local datadir=${1:-/var/lib/dnf/system-upgrade}
    local numpkgs=$(find "$datadir" -name "*.rpm" | wc -l)
    local pkgsize=$(du -sh "$datadir" | cut -f1)
    if [ "$numpkgs" == 0 ]; then
        echo "cache status: $datadir: empty"
        return 1
    else
        echo "cache status: $datadir: $numpkgs pkgs, $pkgsize"
        return 0
    fi
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

# Install a random package so we can test removing it later
runcmd dnf -y install tmux || fail "could not install tmux"

# Download packages for upgrade
runcmd dnf -y system-upgrade download --releasever=$TARGET_RELEASEVER || \
    fail "download returned $?"

# Check cache behavior
check_cache || fail "package cache is empty"
runcmd dnf -y erase tmux || fail "could not remove tmux"
check_cache || fail "erasing package removed upgrade cache"
runcmd dnf -y install tmux || fail "could not install tmux"
check_cache || fail "installing package removed upgrade cache"

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
