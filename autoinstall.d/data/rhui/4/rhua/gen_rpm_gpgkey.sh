#! /bin/bash
set -x

custom_gpg_key=/root/setup/rhui-custom
custom_gpg_conf=/root/setup/rhui-gpg.conf

test -d /root/setup || mkdir -p /root/setup
test -f ${custom_gpg_conf} || (
cat << EOF > ${custom_gpg_conf}
# Default is RSA:
Key-Type: default
# Needed if there are RHEL 5 Clients.
# No subkey, RSA (sign only), to keep compatibility w/ RHEL 5 clients:
#Key-Usage: sign
#Key-Length: 1024
Key-Length: 4096
Subkey-Type: default
Expire-Date: 0
Name-Real: RHUI Admin
Name-Comment: GPG key for RHUI client config RPMs
Passphrase: {{ gpg.passpharase|default('passphrase') }}
%commit
EOF
)

test -d .gnupg/ || (
# to increase entropy on VMs.
rpm -q rng-tools || yum install -y rng-tools
rpm -q rpm-sign  || yum install -y rpm-sign
sed -r 's!ExecStart=.*!& -r /dev/urandom!' /usr/lib/systemd/system/rngd.service > /etc/systemd/system/rngd.service
systemctl restart rngd
cat /proc/sys/kernel/random/entropy_avail
gpg -v --batch --gen-key ${custom_gpg_conf}
)

keyid=$(gpg --list-keys | grep -A 1 '^pub' | tail -1 | sed -e 's/[[:blank:]]\+//')

test -f ${custom_gpg_key} || \
gpg -a --export ${keyid:?} > ${custom_gpg_key}

test -f /root/dot.rpmmacros || (
cat << EOF > /root/dot.rpmmacros
%_signature gpg
%_gpg_name ${keyid:?}
# Needed if there are RHEL 5 Clients
# see: https://access.redhat.com/solutions/874193
#%__gpg_sign_cmd %{__gpg} \
#  gpg --force-v3-sigs --digest-algo=sha1 --batch --no-verbose --no-armor \
#      --passphrase-fd 3 --no-secmem-warning -u "%{_gpg_name}" \
#      -sbo %{__signature_filename} %{__plaintext_filename}
#
#%_binary_payload w9.gzdio
#%_source_payload w9.gzdio
#%_source_filedigest_algorithm 1
#%_binary_filedigest_algorithm 1
#%_default_patch_fuzz 2
EOF
)

(cd /root && test -f .rpmmacros || ln -s dot.rpmmacros .rpmmacros)
#rpm --import ${custom_gpg_key}
# vim:sw=2:ts=2:et:
