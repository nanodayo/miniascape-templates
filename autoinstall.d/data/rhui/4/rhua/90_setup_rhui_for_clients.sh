#! /bin/bash
#
# It does several things to setup RHUI on RHUA.
#
# Prerequisites:
# - rhui-installer was installed from RHUI ISO image
# - CDS are ready and accessible with ssh from RHUA w/o password
# - Gluster FS was setup in CDSes and ready to access from RHUA
#
set -ex

# RHUI_CLIENT_CERTS, RHUI_CLIENT_RPMS
source ${0%/*}/config.sh

RHUI_CLIENT_WORKDIR=${1:-/root/setup/clients/}
RHUI_CLIENT_RPMS_DIR=${RHUI_CLIENT_WORKDIR:?}/rpms

# Generate RPM GPG Key pair to sign RHUI client config RPMs built
test -f ~/.rpmmacros || bash -x ${0%/*}/gen_rpm_gpgkey.sh


# List repos available to clients
rhui-manager --noninteractive client labels

mkdir -p ${RHUI_CLIENT_WORKDIR:?}
while read line
do
    test "x$line" = "x" && continue || :
    name=${line%% *}; repos=${line#* };
    version=`echo "${RHUI_CLIENT_RPM_VERSIONS}" | grep ${name} | cut -f2 -d' '`;
    rhui-manager --noninteractive client rpm \
        --cert --rpm_name ${name:?} --rpm_version ${version:?} \
        --repo_label ${repos:?} \
        --days 3651 --dir ${RHUI_CLIENT_WORKDIR}/
done << EOC
${RHUI_CLIENT_CERTS:?}
EOC

# Check
find ${RHUI_CLIENT_WORKDIR}/ -type f

rpms=$(find ${RHUI_CLIENT_WORKDIR}/ -type f | grep -E '.rpm$')
for rpm in ${rpms}; do echo "# ${rpm##*/}"; rpm -qpl ${rpm}; rpm -qp --scripts ${rpm}; rpm -Kv ${rpm}; done

# vim:sw=4:ts=4:et:
