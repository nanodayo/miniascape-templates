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

# RHUI_CERT_NAME, RHUI_AUTH_OPT, RHUI_CERT, RHUI_REPO_IDS, CURL_PROXY_OPT,
# RH_CDN_URL
source ${0%/*}/config.sh

# Check if RHUA can access https://cdn.redhat.com.
if [ -n "${RH_CDN_URL}" ]; then
    curl -v ${CURL_PROXY_OPT} --cacert /etc/rhsm/ca/redhat-uep.pem --cert ${RHUI_CERT:?} --connect-timeout 5 ${RH_CDN_URL}
fi

# Maybe the auth cache will be expired during 'rhui-manager repo ...' commands
# because it takes some time to finish them. So try to use the auth options...
#RHUI_USERNAME=admin
#RHUI_PASSWORD=$(awk '/rhui_manager_password:/ { print $2; }' /etc/rhui-installer/answers.yaml || echo '')
#test "x${RHUI_PASSWORD}" = "x" && RHUI_AUTH_OPT="" || \
#RHUI_AUTH_OPT="--username ${RHUI_USERNAME:?} --password ${RHUI_PASSWORD:?}"

rhui_installer_logdir="/root/setup/logs"
rhui_installer_log=${rhui_installer_logdir}/rhui-installer.$(date +%F_%T).log
rhui_installer_stamp=${rhui_installer_logdir}/rhui-installer.stamp

# Upload RHUI entitlement cert
if [ -n "${RHUI_CERT_NAME}" ]; then
    test -f /etc/pki/rhui/redhat/${RHUI_CERT_NAME} || \
        rhui-manager ${RHUI_AUTH_OPT} cert upload --cert ${RHUI_CERT}
fi

# List unused (not added) Yum repos as background job.
rhui_repos_list="/root/setup/rhui_repos.txt"
test -f ${rhui_repos_list:?} || \
rhui-manager ${RHUI_AUTH_OPT} repo unused --by_repo_id | tee ${rhui_repos_list:?} &

# Add Yum repos not added yet
f=/tmp/rhui-manager_repo_list.txt
rhui-manager ${RHUI_AUTH_OPT} repo list > $f
repos=""
for rid in ${RHUI_REPO_IDS:?}; do
    grep ${rid} $f || repos="${repos} ${rid}"
done

# It'll take some time to finish the following, e.g. 20 ~ 30 min.
time rhui-manager ${RHUI_AUTH_OPT} repo add_by_repo --repo_ids "$(echo ${repos} | sed 's/ /,/g')"

# Check
rhui-manager ${RHUI_AUTH_OPT} repo list
rhui-manager status
rhui-manager cert info
rct cat-cert /etc/pki/rhui/redhat/*.pem

# vim:sw=4:ts=4:et:
