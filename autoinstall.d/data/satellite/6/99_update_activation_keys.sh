#! /bin/bash
#
# Update activation keys
#
# * associated a lifecycle environment to a key
# * associated a content view to a key
#
# Author: Masatake YAMATO <yamato@redhat.com>
# License: MIT
#
set -ex

# UPDATE_ACTIVATION_KEYS,
source ${0%/*}/config.sh

hammer --csv activation-key list | grep -qE '^1,' && (
while read line; do test "x$line" = "x" || (eval "${line}" || :); done << EOC
${UPDATE_ACTIVATION_KEYS:?}
EOC
)
