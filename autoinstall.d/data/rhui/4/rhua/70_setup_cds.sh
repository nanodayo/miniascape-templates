#! /bin/bash
#
# Adds cds instances.
#
# Prerequisites:
# - rhui-installer was run.
# - CDS are ready and accessible with ssh from RHUA w/o password.
#
set -ex

# CDS_SERVERS
source ${0%/*}/config.sh

for cds in ${CDS_SERVERS:?}; do
    test ${FORCE_ADD_CDS:?} = 1 && \
        rhui-manager --noninteractive cds add --hostname ${cds} --ssh_user root --keyfile_path /root/.ssh/id_rsa_rhua --force \
    || (
        rhui-manager --noninteractive cds list --machine_readable | grep -E "hostname.: .${cds}" || \
        rhui-manager --noninteractive cds add --hostname ${cds} --ssh_user root --keyfile_path /root/.ssh/id_rsa_rhua
    )
done

# Check
rhui-manager --noninteractive cds list

# vim:sw=4:ts=4:et:
