#! /bin/bash
#
# Disable Yum Repos of ISO Images.
#
set -ex

for f in /etc/yum.repos.d/*-iso.repo; do
    save_opt=$(test -f ${f}.save && echo '-i' || echo '-i.save')
    sed ${save_opt} 's/enabled=1/enabled=0/g' $f
done

# vim:sw=4:ts=4:et:
