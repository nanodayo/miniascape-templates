#! /bin/bash
#
# Check whether ipv6 is NOT disabled
#
# - Though IPv6 is not supported yet in satellite 6,
#   ipv6 should not be disabled.
#
#   https://access.redhat.com/solutions/3323821
#   https://access.redhat.com/solutions/3667001
#   https://access.redhat.com/solutions/8709
#
set -ex
ping -q -c 1 -6 ::1

# vim:sw=2:ts=2:et:
