#! /bin/bash
#
# .. seealso:: RHUI 3.0 System Admin Guide, 6.1. Generate an RSA Key Pair: http://red.ht/2r8pkHh
#
set -ex

source ${0%/*}/config.sh

test -f ~/.ssh/id_rsa || ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa

for cds in ${CDS_SERVERS:?} ${LB_SERVERS:?}; do
    (test -f ~/.ssh/known_hosts && \
     grep -E "^$cds" ~/.ssh/known_hosts 2>/dev/null ) || ssh-copy-id ${cds}
done

# Check
for cds in ${CDS_SERVERS:?} ${LB_SERVERS:?}; do
    echo "# Check ${cds}"
    ssh $cds "test -f ./setup/check.sh && time ./setup/check.sh || (hostname -f; date; ip a; ip r)"
done

# vim:sw=4:ts=4:et:
