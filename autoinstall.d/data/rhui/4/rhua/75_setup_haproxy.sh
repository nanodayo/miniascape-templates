#! /bin/bash
set -ex

# LB_SERVERS
source ${0%/*}/config.sh

for lb in ${LB_SERVERS:?}; do
    test ${FORCE_ADD_LB:?} = 1 && \
        rhui-manager --noninteractive haproxy add --hostname ${lb} --ssh_user root --keyfile_path /root/.ssh/id_rsa --force \
    || (
        rhui-manager --noninteractive haproxy list --machine_readable | grep -E "hostname.: .${lb}" || \
        rhui-manager --noninteractive haproxy add --hostname ${lb} --ssh_user root --keyfile_path /root/.ssh/id_rsa
    )
done

# Check
rhui-manager --noninteractive haproxy list

# vim:sw=4:ts=4:et:
