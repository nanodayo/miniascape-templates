#! /bin/bash
#
# It does several things to setup RHUI on RHUA.
#
# Prerequisites:
# - rhui-installer was installed from RHUI ISO image
# - CDS are ready and accessible with ssh from RHUA w/o password
#
set -ex

# RHUI_CLIENT_CERTS, RHUI_CLIENT_RPMS
source ${0%/*}/config.sh

RHUI_CLIENT_WORKDIR=${1:-/root/setup/clients/}
RHUI_CLIENT_RPMS_DIR=${RHUI_CLIENT_WORKDIR:?}/rpms

# Generate RPM GPG Key pair to sign RHUI client config RPMs built
test -f ~/.rpmmacros || bash -x ${0%/*}/gen_rpm_gpgkey.sh

while read line
do
    test "x$line" = "x" && continue || :
    name=${line%% *}; repos=${line#* };
    rhui-manager --noninteractive repo create_custom \
                 --repo_id ${name:?} --protected \
                 --gpg_public_keys ${custom_gpg_key:-/root/setup/rhui-custom}

done << EOC
${RHUI_CLIENT_CERTS:?}
EOC

# Check
rhui-manager --noninteractive repo list


# vim:sw=4:ts=4:et:
