#!/usr/bin/env bash
set -euo pipefail

var_file="/tmp/eco-ci/vars.sh"

function add_var() {
    key="$1"
    value="$2"
    if [ ! -f $var_file ]; then
        touch $var_file
    fi
    echo "${1}=\"${2}\"" >> /tmp/eco-ci/vars.sh
}

function read_vars() {
    if [ -f $var_file ]; then
        source $var_file
    fi
}

function cpu_vars {
    GITHUB_STEP_SUMMARY=${GITHUB_STEP_SUMMARY:-}

    machine_power_data="$1"

    if [[ -f '/proc/cpuinfo' ]]; then
        model_name=$(cat /proc/cpuinfo  | grep 'model name' || true)

        echo "Machine has following CPU Model ${model_name}"

        echo 'Full CPU Info'
        cat /proc/cpuinfo
    else
      echo '/proc/cpuinfo is not accesible ... cannot dump CPU model info'
      model_name='UNKNOWN'
    fi

    if [[ -f '/proc/meminfo' ]]; then
        echo 'Full memory info'
        cat /proc/meminfo
    else
        echo '/proc/meminfo does not exist. Cannot dump memory info'
    fi


    if [[ "$machine_power_data" == "github_EPYC_7763_4_CPU_shared.sh" ]]; then
        echo 'Using github_EPYC_7763_4_CPU_shared.sh';

        add_var 'ECO_CI_MODEL_NAME' 'EPYC_7763';
        # FROM https://datavizta.boavizta.org/serversimpact
        # we assume a disk size of 448 GB total.
        # This totals to 1151.7 kg. With a 4/128 splitting this is 35,990.625 gCO2e
        add_var 'ECO_CI_SCI_M' 35990.625;
        # we use 4 years - 1*60*60*24*365*4 =
        add_var 'ECO_CI_SCI_USAGE_DURATION' 126144000

    # gitlab uses this one https://docs.gitlab.com/ee/ci/runners/hosted_runners/linux.html (Q1/2024)
    # https://www.green-coding.io/case-studies/cpu-utilization-usefulness/
    elif [[ "$machine_power_data" == "gitlab_EPYC_7B12_saas-linux-small-amd64.sh" ]]; then
        echo 'Using gitlab_EPYC_7B12_saas-linux-small-amd64.sh'
        add_var 'ECO_CI_MODEL_NAME' 'EPYC_7B12'
        # we assume a disk size of 1344 GB total according to https://gitlab.com/gitlab-org/gitlab-runner/-/issues/29107
        # which claims runners have 21 GB of disk space with a splitting facttor of 1/64
        # FROM https://datavizta.boavizta.org/serversimpact
        # This totals to 1173.7 kg. With a 1/64 splitting this is 18339,0625 gCO2e
        add_var 'ECO_CI_SCI_M' 18339.0625;
        # we use 4 years - 1*60*60*24*365*4 =
        add_var 'ECO_CI_SCI_USAGE_DURATION' 126144000
    else
        echo "⚠️ Unknown model ${model_name} for estimation, will use default model ... This will likely produce very unaccurate results!"
        [ -n "$GITHUB_STEP_SUMMARY" ] && echo "⚠️ Unknown model ${model_name} for estimation, will use default model ... This will likely produce very unaccurate results!" >> $GITHUB_STEP_SUMMARY
        # we use a default configuration here from https://datavizta.boavizta.org/serversimpact

        add_var 'ECO_CI_MACHINE_POWER_DATA' 'default.sh';

        add_var 'ECO_CI_SCI_M' 800.3;
        # we use 4 years - 1*60*60*24*365*4 =
        add_var 'ECO_CI_SCI_USAGE_DURATION' 126144000
        add_var 'ECO_CI_MODEL_NAME' 'unknown';
    fi
}
