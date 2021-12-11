#! /bin/bash
#
# An experimental and temporary workaround for rhbz#1593218.
#
# Author: Satoru SATOH <ssato@redhat.com>
# License: MIT
#
set -e

REPOS_TOPDIR=/var/lib/rhui/remote_share/published/yum/master/yum_distributor/
KEEP=1  # How many recent updateinfo.xml.gz are kept.
DO_REMOVE=no

function show_help () {
    cat << EOH
Usage: $0 [Options...]
Options:
    -r            Remove older updateinfo.xml.gz files instead of print them.
    -h            Show this help.
EOH
}

while getopts k:rh OPT
do
    case "${OPT}" in
        r) DO_REMOVE=yes
           ;;
        h) show_help; exit 0
           ;;
        \?) echo "Invalid option!"; exit 1
           ;;
    esac
done
shift $((OPTIND - 1))

for repodata_dir in ${REPOS_TOPDIR:?}/*/*/repodata/; do
    repomdxml=${repodata_dir}/repomd.xml
    test -f ${repomdxml} || continue

    latest=$(sed -nr 's,.* href="repodata/(.+-updateinfo.xml.gz)" .*,\1,p' ${repomdxml})
    removes=$(ls -1 ${repodata_dir}/*-updateinfo.xml.gz | grep -vE ".*/${latest:?}")

    [[ -n "${removes}" ]] || continue
    [[ ${DO_REMOVE:?} = "yes" ]] && rm -f ${removes} || {
        for r in ${removes}; do [[ -n ${r} ]] && echo $r || :; done
    }
done

# vim:sw=4:ts=4:et:
