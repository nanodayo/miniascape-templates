CURDIR=${0%/*}

function _ssh_exec () { ssh -o ConnectTimeout=5 $@; }
function _ssh_exec_script () { ssh -o ConnectTimeout=5 $1 /bin/bash; }

# TODO: Find out ISO images automatically, for example:
#
#   RHEL_ISO=$(ls -1t ${CURDIR:?}/rhel-*.iso | head -n 1)
#   RHUI_ISO=$(ls -1t ${CURDIR:?}/RHUI-*.iso | head -n 1)
#   RHGS_ISO=$(ls -1t ${CURDIR:?}/rhgs-*.iso | head -n 1)
#
RHEL_ISO={{ rhui.rhel_iso|default('rhel-server-7.6-x86_64-dvd.iso') }}
RHUI_ISO={{ rhui.rhui_iso|default('RHUI-3.0-RHEL-7-20181106.0-RHUI-x86_64-dvd1.iso') }}
RHGS_ISO={{ rhui.rhgs_iso|default('rhgs-3.4-rhel-7-x86_64-dvd-2.iso') }}

{%- if proxy is defined and proxy.fqdn is defined %}
CURL_PROXY_OPT="--proxy https://{{ proxy.fqdn }}:{{ proxy.port|default("443") }}"
{%-    if proxy.user is defined %}
CURL_PROXY_OPT="${CURL_PROXY_OPT} --proxy-user {{ proxy.user }}:{{ proxy.password }}"
{%-    endif %}
{% endif %}

RHUA={{ rhui.rhua.fqdn }}

CDS_SERVERS="
{%- for cds in rhui.cds.servers -%}
{{      cds.fqdn }}
{%  endfor -%}
"
{% if rhui.lb is defined and rhui.lb -%}
LB_SERVERS="
{%-     for lb in rhui.lb.servers -%}
{{          lb.fqdn }}
{%      endfor -%}
"
{%- endif %}

CDS_0={{ rhui.cds.servers[0].fqdn }}
CDS_REST="{% for cds in rhui.cds.servers %}{% if not loop.first %}{{ cds.fqdn }} {% endif %}{% endfor %}"
CDS_LB_HOSTNAME={{ rhui.cds.fqdn }}

# Set to 1 if run 'rhui cds add ...' more than twice.
FORCE_ADD_CDS=0
FORCE_ADD_LB=0

NUM_CDS={{ rhui.cds.servers|length }}

# RHUA, CDS and LB will access yum repos via http on this host.
YUM_REPO_SERVER=${CDS_0:?}

# If RHUI_STORAGE_TYPE is Gluster Storage.
BRICK=/export/brick
GLUSTER_BRICKS="
{%- for cds in rhui.cds.servers -%}
{{      cds.fqdn }}:${BRICK:?} {% endfor -%}
"
GLUSTER_FIREWALL_NICS="{{ rhui.storage.interfaces|join(' ')|default('') }}"
test "x${GLUSTER_FIREWALL_NICS}" = "x" || \
GLUSTER_ADD_FIREWALL_RULES="
systemctl is-active firewalld 2>/dev/null && \
(
for nic in ${GLUSTER_FIREWALL_NICS}; do
    zone=\$(firewall-cmd --get-zone-of-interface=\${nic});
    firewall-cmd --add-service=glusterfs --zone=\${zone} --permanent;
    firewall-cmd --add-service=glusterfs --zone=\${zone};
done;
firewall-cmd --reload
) || :
"

RH_CDN_URL=https://cdn.redhat.com/content/dist/rhel/rhui/server/7/7Server/x86_64/os/repodata/repomd.xml

RHUI_STORAGE_TYPE={{ rhui.storage.fstype }}
RHUI_STORAGE_MOUNT={{ rhui.storage.server }}:{{ rhui.storage.mnt }}
RHUI_STORAGE_MOUNT_OPTIONS="{{ rhui.storage.mnt_options|join(',')|default('rw') }}"

RHUI_INSTALLER_TLS_OPTIONS="--certs-country {{ rhui.tls.country|default('JP') }} --certs-state {{ rhui.tls.state|default('Tokyo') }} --certs-city {{ rhui.tls.city }} --certs-org {{ rhui.tls.org }} --certs-org-unit {{ rhui.tls.unit|default('Cloud') }}"
{%- if proxy is defined and proxy.fqdn is defined %}
RHUI_INSTALLER_TLS_OPTIONS="${RHUI_INSTALLER_TLS_OPTIONS:?} --proxy-protocol {{ proxy.protocol|default('http') }} --proxy-hostname {{ proxy.fqdn }} --proxy-port {{ proxy.port|default("443") }}"
{%-    if proxy.user is defined %}
RHUI_INSTALLER_TLS_OPTIONS="${RHUI_INSTALLER_TLS_OPTIONS:?} --proxy-username {{ proxy.user }} --proxy-password {{ proxy.password }}"
{%-    endif %}
{%- endif %}

RHUI_REPO_IDS="
{%- for repo in rhui.repos if repo.id is defined and repo.id -%}
{{      repo.id }}
{% endfor -%}
"

# Name of RPMs and certs are same.
# format: <client_rpm_name == client_cert_name> <client_rpm_repo_0> [<client_rpm_repo_1> ...]
RHUI_CLIENT_CERTS="
{%- for crpm in rhui.client_rpms -%}
{{      crpm.name }} {{ crpm.repos|join(',') }}
{% endfor -%}
"

# format: <client_rpm_name> <client_rpm_repo_0> [<client_rpm_repo_1> ...]
RHUI_CLIENT_RPMS="
{%- for crpm in rhui.client_rpms if crpm.name is defined and crpm.name -%}
{{      crpm.name }} {{ crpm.version|default('1.0') }}
{% endfor -%}
"

# vim:sw=4:ts=4:et:
