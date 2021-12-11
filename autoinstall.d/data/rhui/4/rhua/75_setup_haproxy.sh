#! /bin/bash
set -ex

# RHUI_AUTH_OPT, CDS_SERVERS
source ${0%/*}/config.sh

RHUI_AUTH_OPT=""  # Force set empty to avoid to password was printed.

for lb in ${LB_SERVERS:?}; do
    test ${FORCE_ADD_LB:?} = 1 && \
        rhui-manager ${RHUI_AUTH_OPT} haproxy add --hostname ${lb} --ssh_user root --keyfile_path /root/.ssh/id_rsa --force \
    || (
        rhui-manager ${RHUI_AUTH_OPT} haproxy list --machine_readable | grep -E "hostname.: .${lb}" || \
        rhui-manager ${RHUI_AUTH_OPT} haproxy add --hostname ${lb} --ssh_user root --keyfile_path /root/.ssh/id_rsa
    )
done

# Check
rhui-manager haproxy list

# vim:sw=4:ts=4:et:
