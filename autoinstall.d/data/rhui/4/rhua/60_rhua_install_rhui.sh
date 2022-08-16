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

# CDS_LB_HOSTNAME, RHUI_STORAGE_TYPE, RHUI_STORAGE_MOUNT,
# RHUI_STORAGE_MOUNT_OPTIONS, RHUI_INSTALLER_TLS_OPTIONS
source ${0%/*}/config.sh

rhui_installer_logdir="/root/setup/logs"
rhui_installer_log=${rhui_installer_logdir}/rhui-installer.$(date +%F_%T).log
rhui_installer_stamp=${rhui_installer_logdir}/rhui-installer.stamp

mkdir -p ${rhui_installer_logdir}
test -f ${rhui_installer_stamp} || \
(
rhui_installer_options="\
--cds-lb-hostname ${CDS_LB_HOSTNAME:?} \
--remote-fs-type ${RHUI_STORAGE_TYPE:?} \
--remote-fs-server ${RHUI_STORAGE_MOUNT:?} \
--rhua-mount-options ${RHUI_STORAGE_MOUNT_OPTIONS:?} \
--rhua-hostname ${RHUA:?}
"

rhui-installer \
    ${rhui_installer_common_options} \
    ${rhui_installer_options:?} \
    "${RHUI_INSTALLER_TLS_OPTIONS[@]:?}" \
| tee 2>&1 ${rhui_installer_log} && \
touch ${rhui_installer_stamp}
)

# Generate auth cache
grep password /etc/rhui/rhui-subscription-sync.conf
rhui-manager

# Check
s=${0%/*}/collect_rhui-manager_help_recur.sh
test -x $s && time $s || :

# vim:sw=4:ts=4:et:
