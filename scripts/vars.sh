#!/usr/bin/env bash
set -euo pipefail

var_file="/tmp/eco-ci/vars.sh"

function add_var() {
    local key="$1"
    local value="$2"
    if [ ! -f $var_file ]; then
        touch $var_file
    fi
    echo "${1}='${2}'" >> /tmp/eco-ci/vars.sh
}

function read_vars() {
    if [ -f $var_file ]; then
        source $var_file
    fi
}

function initialize_vars() {
    echo > /tmp/eco-ci/vars.sh
}

function cpu_vars {
    GITHUB_STEP_SUMMARY=${GITHUB_STEP_SUMMARY:-}

    local machine_power_data="$1"

    if [[ -f '/proc/cpuinfo' ]]; then
        local model_name=$(cat /proc/cpuinfo  | grep 'model name' || true)

        echo "Machine has following CPU Model ${model_name}"

        echo 'Full CPU Info'
        cat /proc/cpuinfo
    else
      echo '/proc/cpuinfo is not accessible ... cannot dump CPU model info' >&2
      local model_name='UNKNOWN'
    fi

    if [[ -f '/proc/meminfo' ]]; then
        echo 'Full memory info'
        cat /proc/meminfo
    else
        echo '/proc/meminfo does not exist. Cannot dump memory info' >&2
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
        # which claims runners have 21 GB of disk space with a splitting factor of 1/64
        # FROM https://datavizta.boavizta.org/serversimpact
        # This totals to 1173.7 kg. With a 1/64 splitting this is 18339.0625 gCO2e
        add_var 'ECO_CI_SCI_M' 18339.0625;
        # we use 4 years - 1*60*60*24*365*4 =
        add_var 'ECO_CI_SCI_USAGE_DURATION' 126144000
    elif [[ "$machine_power_data" == "gitlab_EPYC_7B12_saas-linux-medium-amd64.sh" ]]; then
        echo 'Using gitlab_EPYC_7B12_saas-linux-medium-amd64.sh'
        add_var 'ECO_CI_MODEL_NAME' 'EPYC_7B12_medium'
        # we assume a disk size of 1344 GB total according to https://gitlab.com/gitlab-org/gitlab-runner/-/issues/29107
        # which claims runners have ~50 GB of disk space with a splitting factor of 2/64
        # FROM https://datavizta.boavizta.org/serversimpact
        # This totals to 1173.7 kg. With a 2/64 splitting this is 36678.125 gCO2e
        add_var 'ECO_CI_SCI_M' 36678.125;
        # we use 4 years - 1*60*60*24*365*4 =
        add_var 'ECO_CI_SCI_USAGE_DURATION' 126144000

    # GitHub uses this one https://docs.github.com/en/actions/using-github-hosted-runners/using-github-hosted-runners/about-github-hosted-runners#standard-github-hosted-runners-for--private-repositories (Q1/2025)
    # https://www.green-coding.io/case-studies/cpu-utilization-usefulness/
    elif [[ "$machine_power_data" == "macos-13-mac-mini-intel.sh" ]]; then
        echo 'Using macos-13-mac-mini-intel.sh'
        add_var 'ECO_CI_MODEL_NAME' 'Intel_Core_i3-8100'
        # [GitHub specs](https://docs.github.com/en/actions/using-github-hosted-runners/using-github-hosted-runners/about-github-hosted-runners#standard-github-hosted-runners-for--private-repositories)
        # [Source for hardware specs](https://en.wikipedia.org/wiki/Mac_Mini#Technical_specifications_3)
        # [Source for CPU specs](https://www.intel.com/content/www/us/en/products/sku/126688/intel-core-i38100-processor-6m-cache-3-60-ghz/specifications.html)
        # It seems GitHub is not sharing this machine for the runners and is just running some virtualization layer, as some memory is reserved ...?
        # FROM official Apple LCA for MacMini October 208
        # 270 kg
        add_var 'ECO_CI_SCI_M' 270000.00;
        # we use 4 years - 1*60*60*24*365*4 =
        add_var 'ECO_CI_SCI_USAGE_DURATION' 126144000
    # GitHub uses this one https://docs.github.com/en/actions/using-github-hosted-runners/using-github-hosted-runners/about-github-hosted-runners#standard-github-hosted-runners-for--private-repositories (Q1/2025)
    # https://www.green-coding.io/case-studies/cpu-utilization-usefulness/
    elif [[ "$machine_power_data" == "macos-14-mac-mini-m1.sh" ]]; then
        echo 'Using macos-14-mac-mini-m1.sh'
        add_var 'ECO_CI_MODEL_NAME' 'Apple_M1'
        # [GitHub specs](https://docs.github.com/en/actions/using-github-hosted-runners/using-github-hosted-runners/about-github-hosted-runners#standard-github-hosted-runners-for--private-repositories)
        # [Source for full Mac Mini power consumption](https://www.anandtech.com/show/16252/mac-mini-apple-m1-tested)
        # [Source for Cores and RAM of total machine (assuming only efficiency cores used for hypervisor and performance for runners)](https://github.blog/news-insights/product-news/introducing-the-new-apple-silicon-powered-m1-macos-larger-runner-for-github-actions/) (We slightly tuned vhost-ratio to 0.3 instead of 0.4 to adapt to the measured power source from Source #1)
        # FROM official Apple LCA for Mac mini (November 2020)
        # 172 kg
        # With a 0.3 splitting this is 51600.00 gCO2e
        add_var 'ECO_CI_SCI_M' 51600.00;
        # we use 4 years - 1*60*60*24*365*4 =
        add_var 'ECO_CI_SCI_USAGE_DURATION' 126144000
	elif [[ "$machine_power_data" == "intel-xeon-6246_vhr_04167.sh" ]]; then
        echo 'Using intel-xeon-6246_vhr_04167.sh'
        add_var 'ECO_CI_MODEL_NAME' 'Intel_Xeon_6246'
		
		# 1x SSD (960 GB)
		# 12x RAM (32 GB)
		# 2x CPU (24 cores, 165 TDP)
		add_var 'ECO_CI_SCI_M' 932.8;
        # we use 4 years - 1*60*60*24*365*4 =
        add_var 'ECO_CI_SCI_USAGE_DURATION' 126144000
    else
        echo "⚠️ Unknown model ${model_name} for estimation, will use default model ... This will likely produce very unaccurate results!" >&2
        [ -n "$GITHUB_STEP_SUMMARY" ] && echo "⚠️ Unknown model ${model_name} for estimation, will use default model ... This will likely produce very unaccurate results!" >> $GITHUB_STEP_SUMMARY
        # we use a default configuration here from https://datavizta.boavizta.org/serversimpact

        add_var 'ECO_CI_MACHINE_POWER_DATA' 'default.sh';

        add_var 'ECO_CI_SCI_M' 800.3;
        # we use 4 years - 1*60*60*24*365*4 =
        add_var 'ECO_CI_SCI_USAGE_DURATION' 126144000
        add_var 'ECO_CI_MODEL_NAME' 'unknown';
    fi
}
