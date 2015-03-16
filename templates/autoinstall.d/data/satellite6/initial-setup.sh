#! /bin/bash
set -e

# Defaults:
USE_DEFAULT=0

ADMIN={{ satellite.admin.name|default('admin') }}
PASSWORD="{{ satellite.admin.password|default('') }}"
ORGANIZATION={{ satellite.organization|default('Default_Organization') }}
LOCATION={{ satellite.location|default('Default_Location') }}
MANIFETS_FILE={{ satellite.manifests_file|default('manifests.zip') }}

LOGDIR=logs


# @see http://gsw-hammer.documentation.rocks/initial_configuration,_adding_red_repos/hammer_credentials.html
function guess_admin_password () {
    sed -nr 's/^ *admin_password: ([^[:blank:]]+) *$/\1/p' \
        /etc/katello-installer/answers.katello-installer.yaml
}

function setup_hammer_userconf () {
    local admin_username=${1:-$ADMIN}
    local admin_password=${2:-$PASSWORD}

    local userconf=$HOME/.hammer/cli_config.yml
    local sysconf=/etc/hammer/cli.modules.d/foreman.yml

    if test -f ${userconf:?}; then
        echo "[Info] ${userconf} already exists! Nothing to do."
    else
        if test -f ${sysconf:?}; then
            if test "x${admin_password:?}" = "x"; then
                #read -s -p "Password: " -t 20 admin_password
                admin_password=`guess_admin_password`
            fi
            test -d ${userconf%/*} || mkdir -m 0700 ${userconf%/*}
            touch ${userconf} && chmod 0600 ${userconf}
            cat << EOF > ${userconf}
`cat ${sysconf}`

  :username: '${admin_username:?}'
  :password: '${admin_password:?}'
EOF
        else
            echo "[Warn] System configuration ${sysconf} does not exist! Check your installation of satellite 6"
            return 1
        fi
    fi
}

function setup_org_and_location () {
    local org=${1:-$ORGANIZATION}
    local location=${2:-$ORGANIZATION}
    local admin=${3:-$ADMIN}

    if test "x${org:?}" != "x${ORGANIZATION}"; then
        hammer organization create --name="${org}" --label="${org}"
    fi

    if test "x${location:?}" != "x${LOCATION}"; then
        hammer location create --name="${location}"
    fi

    # TODO: Which of the followings are necessary?
    hammer location add-user --name="${location}" --user="${admin}"
    hammer location add-organization --name="${location}" --organization="${org}"
    hammer organization add-user --name="${org}" --user="${admin:?}"
}

function upload_manifests () {
    local manifests_file=${1:-$MANIFETS_FILE}
    local org=${2:-$ORGANIZATION}
    local product="${3:-Red Hat Enterprise Linux Server}"
    local logdir=${4:-$LOGDIR}

    test -d ${logdir} || mkdir -p ${logdir}

    hammer subscription upload --organization "${org}" --file ${manifests_file:?}
    hammer product list --organization "${org}" --full-results | \
        tee ${logdir}/product.list
    hammer repository-set list --organization "${org}" --product "${product:?}" | \
        tee ${logdir}/rhel-server-repos.list
}

function setup_repo () {
    local name="$1"   # ex. 'Red Hat Enterprise Linux 6 Server (RPMs)'
    local releasever="$2"  # ex. '6Server'
    local basearch=${3:-x86_64}
    local org=${4:-$ORGANIZATION}
    local product="${5:-Red Hat Enterprise Linux Server}"

    hammer repository-set enable \
        --organization "${org:?}" --product "${product:?}" \
        --name "${name:?}" \
        --basearch ${basearch:?} --releasever=${releasever:?}
}

function setup_product () {
    local org=${1:-$ORGANIZATION}
    local product="${2:-Red Hat Enterprise Linux Server}"
    local logdir=${3:-$LOGDIR}

    local repos_csv=${logdir:?}/repos_$(echo ${product:?} | tr ' ' _).csv
    local sync_plan_name="Daily sync"

    test -d ${logdir} || mkdir -p ${logdir}

    hammer --csv repository list --organization "${org:?}" | tee ${repos_csv:?}
    for rid in $(sed -nr 's/^([[:digit:]]+),.*/\1/p' ${repos_csv})
    do
        hammer repository synchronize --organization "${org}" \
            --id ${rid:?} --async
    done

    hammer sync-plan create --organization "${org}" \
        --interval daily --name "${sync_plan_name:?}"
    hammer sync-plan list --organization "${org}"
    hammer product set-sync-plan --organization "${org}" --name "${product}" \
        --sync-plan "${sync_plan_name}"  # Or --sync-plan-id 1
}

function setup_content_view () {
    local name="${1:?}"
    local repo_name_pattern="${2:?}"  # ex. 'Red Hat Enterprise Linux 6'
    local org=${3:-$ORGANIZATION}

    hammer content-view create --organization "${org:?}" --name "${name:?}"
    for rid in \
        $(hammer --csv repository list --organization "${org}" | \
          sed -nr "s/^([[:digit:]]+),${repo_name_pattern}.*/\1/p")
    do
        hammer content-view add-repository --organization "${org}" | \
            --name "${name:?}" --repository-id ${rid:?}
    done
    hammer content-view publish --organization "${org:?}" --name "${name:?}"
}

function create_host_collection() {
    local collection=${1:?}
    local org=${2:-$ORGANIZATION}

    hammer host-collection create --organization "${org}" --name "${collection:?}"
}

function create_activation_key () {
    local name="${1:?}"
    local content_view="${2:?}"
    local lifecycle_env="${3:?}"
    local org=${4:-$ORGANIZATION}

    hammer activation-key create --organization "${org}" \
        --name "${collection:?}" \
        --content-view "${content_view:?}" \
        --lifecycle-environment "${lifecycle_env:?}"

# TODO: --max-content-hosts | --unlimited-content-hosts \
}

# pre-defined and common tasks:
function setup_rhel_6_repos () {
    local org=${1:-$ORGANIZATION}

    setup_repo 'Red Hat Enterprise Linux 6 Server (RPMs)' \
        '6Server' 'x86_64' "${org:?}"
    setup_repo 'Red Hat Enterprise Linux 6 Server - RH Common (RPMs)' \
        '6Server' 'x86_64' "${org:?}"
    setup_repo 'Red Hat Enterprise Linux 6 Server - Optional (RPMs)' \
        '6Server' 'x86_64' "${org:?}"
}

function setup_user_given_repos () {
    local org=${1:-$ORGANIZATION}
{% for repo in satellite.repos if repo.name and repo.releasever -%}
    setup_repo '{{ repo.name }}' \
        '{{ repo.releasever }}' '{{  repo.arch|default("x86_64") }}' "${org:?}"
{% endfor %}
}

function setup_rhel_6_content_view () {
    local name="${1:-CV_RHEL_6}"
    local org=${2:-$ORGANIZATION}

    setup_content_view "${name:?}" "Red Hat Enterprise Linux 6" "${org:?}"
}

# FIXME: Define function to create lifecycle environments allow user
# customizations.
function setup_lifecycle_env_path_0 () {
    local org=${1:-$ORGANIZATION}

    hammer lifecycle-environment create --organization "${org}" \
        --name Test --prior Library
    hammer lifecycle-environment create --organization "${org}" \
        --name Prod --prior Test
}

function setup_rhel_6_activation_keys () {
    local org=${1:-$ORGANIZATION}

    create_activation_key "AK_CV_RHEL_6_Test" "CV_RHEL_6" "Test" "${org:?}"
    create_activation_key "AK_CV_RHEL_6_Prod" "CV_RHEL_6" "Prod" "${org:?}"
}


usage="Usage: $0 [OPTIONS]"

function show_help () {
  cat <<EOH
$usage
Options:
  -a ADMIN  Admin name [$ADMIN]
  -o ORG    Organization to create and setup [$ORGANIZATION]
  -l LOC    Location to create and setup [$LOCATION]
  -M FILE   Path to manifests file [$MANIFETS_FILE]

  -D        Initialize with script default settings

  -h        Show this help and exit.

Examples:
 $0 -D
EOH
}


# main:
while getopts "a:o:l:M:Dh" opt
do
  case $opt in
    a) ADMIN=$OPTARG ;;
    o) ORGANIZATION=$OPTARG ;;
    l) LOCATION=$OPTARG ;;
    M) MANIFETS_FILE=$OPTARG ;;
    D) USE_DEFAULT=1 ;;
    h) show_help; exit 0 ;;
    \?) show_help; exit 1 ;;
  esac
done
shift $(($OPTIND - 1))

if test "x${USE_DEFAULT:?}" = "x1"; then
    setup_hammer_userconf ${ADMIN}
    setup_org_and_location "${ORGANIZATION}" "${LOCATION}" ${ADMIN}
    upload_manifests ${MANIFETS_FILE} "${ORGANIZATION}"

    setup_rhel_6_repos "${ORGANIZATION}"
    setup_product "${ORGANIZATION}"
    setup_rhel_6_content_view "CV_RHEL_6" "${ORGANIZATION}"
    setup_lifecycle_env_path_0 "${ORGANIZATION}"
    setup_rhel_6_activation_keys "${ORGANIZATION}"
fi

# vim:sw=4:ts=4:et:
