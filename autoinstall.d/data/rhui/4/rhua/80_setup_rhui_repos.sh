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

# RHUI_REPO_IDS, CURL_PROXY_OPT,
# RH_CDN_URL
source ${0%/*}/config.sh

# Check if RHUA can access https://cdn.redhat.com.
if [ -n "${RH_CDN_URL}" ]; then
    # You can add "--cert /etc/pki/rhui/redhat/foo.pem" to the next command line.
    curl -v ${CURL_PROXY_OPT} --cacert /etc/rhsm/ca/redhat-uep.pem --connect-timeout 5 ${RH_CDN_URL}
fi

rhui_installer_logdir="/root/setup/logs"
rhui_installer_log=${rhui_installer_logdir}/rhui-installer.$(date +%F_%T).log
rhui_installer_stamp=${rhui_installer_logdir}/rhui-installer.stamp

# List unused (not added) Yum repos as background job.
rhui_repos_list="/root/setup/rhui_repos.txt"
test -f ${rhui_repos_list:?} || \
rhui-manager --noninteractive repo unused --by_repo_id | tee ${rhui_repos_list:?}

# Add Yum repos not added yet
f=/tmp/rhui-manager_repo_list.txt
rhui-manager --noninteractive repo list > $f
repos=""
for rid in ${RHUI_REPO_IDS:?}; do
    grep ${rid} $f || repos="${repos} ${rid}"
done

# It'll take some time to finish the following, e.g. 20 ~ 30 min.
time rhui-manager --noninteractive repo add_by_repo --repo_ids "$(echo ${repos} | sed 's/ /,/g')"

# Check
rhui-manager --noninteractive repo list
rhui-manager --noninteractive status
rhui-manager --noninteractive cert info
rct cat-cert /etc/pki/rhui/redhat/*.pem

# vim:sw=4:ts=4:et:
