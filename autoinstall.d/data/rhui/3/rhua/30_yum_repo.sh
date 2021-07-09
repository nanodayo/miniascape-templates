#! /bin/bash
#
# Setup Yum repos on the primary CDS host for RHUI servers.
#
# Prerequisites:
# - RHEL, RHUI and RH Gluster FS ISO images
# - SSH access to the primary CDS will serve yum repos from RHUA
# 
set -ex

# YUM_REPO_SERVER, CDS_SERVERS, RHUI_STORAGE_TYPE, RHEL_ISO, RHUI_ISO, RHGS_ISO
source ${0%/*}/config.sh

ISO_DIR=${1:-/root/setup/}

MNT_DIR=/var/www/html
RHEL_SUBDIR=pub/rhel-7.x/
RHUI_SUBDIR=pub/rhui-3.x/
RHGS_SUBDIR=pub/rhgs-3.x/

# RHEL
f=/etc/yum.repos.d/rhel-7.x-iso.repo
test -f $f || \
cat << EOF > /etc/yum.repos.d/rhel-7.x-iso.repo
[rhel-7.x]
name=RHEL 7.x
baseurl=http://${YUM_REPO_SERVER:?}/${RHEL_SUBDIR}/
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release
gpgcheck=1
enabled=1
EOF
for cds in ${CDS_SERVERS:?}; do scp $f $cds:/etc/yum.repos.d/; done

cat << EOC | _ssh_exec_script ${YUM_REPO_SERVER:?}
test -d ${MNT_DIR}/${RHEL_SUBDIR}/Packages || (
mkdir -p ${MNT_DIR}/${RHEL_SUBDIR}
test -f ${ISO_DIR}/${RHEL_ISO} && \
mount -o ro,loop ${ISO_DIR}/${RHEL_ISO:?} ${MNT_DIR}/${RHEL_SUBDIR} || \
{
    echo "*** ${ISO_DIR}/${RHEL_ISO} was not found! ***";
    echo "*** Copy its contents into ${MNT_DIR}/${RHEL_SUBDIR}/ somehow by yourself. ***";
}
)
EOC

# RHUI
f=/etc/yum.repos.d/rhui-3.x-iso.repo
test -f $f || \
cat << EOF > /etc/yum.repos.d/rhui-3.x-iso.repo
[rhui-3.x]
name=RHUI 3.x
baseurl=http://${YUM_REPO_SERVER}/${RHUI_SUBDIR}/
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release
gpgcheck=1
enabled=1
EOF
for cds in ${CDS_SERVERS:?}; do scp $f $cds:/etc/yum.repos.d/; done

cmds="
test -d ${MNT_DIR}/${RHUI_SUBDIR}/Packages || (
mkdir -p ${MNT_DIR}/${RHUI_SUBDIR}
test -f ${ISO_DIR}/${RHUI_ISO} && \
mount -o ro,loop ${ISO_DIR}/${RHUI_ISO:?} ${MNT_DIR}/${RHUI_SUBDIR} || \
{
    echo \"*** ${ISO_DIR}/${RHUI_ISO} was not found! ***\";
    echo \"*** Copy its contents into ${MNT_DIR}/${RHUI_SUBDIR}/ somehow by yourself. ***\";
}
)
"
cat << EOC | _ssh_exec_script ${YUM_REPO_SERVER:?}
${cmds:?}
EOC

# RHGS
if test "x${RHUI_STORAGE_TYPE:?}" = "xglusterfs"; then
    f=/etc/yum.repos.d/rhgs-3.x-iso.repo
    test -f $f || \
    cat << EOF > /etc/yum.repos.d/rhgs-3.x-iso.repo
[rhgs-3.x]
name=RH Gluset Storage 3.x
baseurl=http://${YUM_REPO_SERVER}/${RHGS_SUBDIR}/
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release
gpgcheck=1
enabled=0
EOF
    for cds in ${CDS_SERVERS:?}; do scp $f $cds:/etc/yum.repos.d/; done
        cmds="test -d ${MNT_DIR}/${RHGS_SUBDIR}/Packages || (
mkdir -p ${MNT_DIR}/${RHGS_SUBDIR}
test -f ${ISO_DIR}/${RHGS_ISO} && \
mount -o ro,loop ${ISO_DIR}/${RHGS_ISO:?} ${MNT_DIR}/${RHGS_SUBDIR} || \
{
    echo \"*** ${ISO_DIR}/${RHGS_ISO} was not found! ***\";
    echo \"*** Copy its contents into ${MNT_DIR}/${RHGS_SUBDIR}/ somehow by yourself. ***\";
}
)
"
    cat << EOC | _ssh_exec_script ${YUM_REPO_SERVER:?}
${cmds:?}
EOC
fi

# Make yum repos served.
cmds="
(rpm -q httpd || yum install -y httpd) && \
systemctl is-active httpd 2>/dev/null || systemctl start httpd
systemctl status httpd
yum repolist
"
cat << EOC | _ssh_exec_script ${YUM_REPO_SERVER:?}
${cmds:?}
EOC

# Check
yum repolist
test "x${RHUI_STORAGE_TYPE:?}" = "xglusterfs" && yum repolist --enablerepo rhgs-3.x || :

# vim:sw=4:ts=4:et:
