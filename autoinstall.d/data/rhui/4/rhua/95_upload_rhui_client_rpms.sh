#! /bin/bash
#
# It does several things to setup RHUI on RHUA.
#
# Prerequisites:
# - rhui-installer was installed
# - CDS are ready and accessible with ssh from RHUA w/o password
# - Custom repositories are created(same name client rpms)
# - RHUI client rpms are signed
#
set -ex

# RHUI_CLIENT_CERTS, RHUI_CLIENT_RPMS
source ${0%/*}/config.sh

RHUI_CLIENT_WORKDIR=${1:-/root/setup/clients/}
RHUI_CLIENT_RPMS_DIR=${RHUI_CLIENT_WORKDIR:?}/rpms

# Check
find ${RHUI_CLIENT_WORKDIR}/ -type f

rpms=$(find ${RHUI_CLIENT_WORKDIR}/ -type f | grep -E '.rpm$')
for rpm in ${rpms}; do echo "# ${rpm##*/}"; rpm -qpl ${rpm}; rpm -qp --scripts ${rpm}; rpm -Kv ${rpm}; done

while read line
do
    test "x$line" = "x" && continue || :
    name=${line%% *}; version=${line#* };
    rhui-manager --noninteractive packages upload \
        --repo_id ${name:?} \
        --packages ${RHUI_CLIENT_WORKDIR}/${name:?}-${version:?}/build/RPMS/noarch/${name:?}-${version:?}*.rpm
    # check
    rhui-manager --noninteractive repo info \
        --repo_id ${name:?}
done << EOC
${RHUI_CLIENT_RPM_VERSIONS:?}
EOC

# vim:sw=4:ts=4:et:
