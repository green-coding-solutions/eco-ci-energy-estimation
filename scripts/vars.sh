#!/usr/bin/env bash
set -euo pipefail

add_var() {
    key=$1
    value=$2
    file="/tmp/eco-ci/vars.json"
    #check if /tmp/eco-ci directory exists, if not make it
    if [ ! -d "/tmp/eco-ci" ]; then
        mkdir -p "/tmp/eco-ci"
    fi

    echo "vars.sh having $1 and $2"

    # Check if the JSON file exists
    if [ ! -f $file ]; then
        # Create a new JSON file with the key-value pair
        echo "{\"$key\": \"$value\"}" > $file
    else
        # Update or add the key-value pair in the JSON file
        # check if the key exists in the json file with jq
        if [[ $(jq ".$key" $file) == "null" ]]; then
            # add the key-value pair to the json file
            jq --arg key "$key" --arg value "$value" '. + {($key): $value}' "$file" > "/tmp/eco-ci/vars.json.tmp" && mv "/tmp/eco-ci/vars.json.tmp" "$file"
        else
            # update the key-value pair in the json file
            jq --arg key "$key" --arg value "$value" '.[$key] = $value' "$file" > "/tmp/eco-ci/vars.json.tmp" && mv "/tmp/eco-ci/vars.json.tmp" "$file"
        fi
    fi
}

read_vars() {
    dict_file="/tmp/eco-ci/vars.json"

    echo "Catting var file"
    cat /tmp/eco-ci/vars.json

    if [[ -f "$dict_file" ]]; then
        # Read the JSON file and extract key-value pairs
        while IFS="=" read -r key value; do
            # Trim leading/trailing whitespace and quotes from the key
            key=$(echo "$key" | sed -e 's/^"//' -e 's/"$//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

            # Trim leading/trailing whitespace and quotes from the value
            value=$(echo "$value" | sed -e 's/^"//' -e 's/"$//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

            # Set the key-value pair as an environment variable
            export "$key"="$value"
        done < <(jq -r 'to_entries[] | "\(.key)=\(.value)"' "$dict_file")
    fi
}

function cpu_vars_fill {

    machine_power_data=$1

    model_name=$(cat /proc/cpuinfo  | grep "model name")
    echo "Currently running on follow CPU Model ${model_name}"

    echo "Full CPU Info"
    cat /proc/cpuinfo

    echo "Full memory info"
    cat /proc/meminfo

    if [[ $machine_power_data == '' ]]; then
        echo "⚠️ Unknown model $model_name for estimation, will use default model ... This will likely produce very unaccurate results!"
        [ -n "$GITHUB_STEP_SUMMARY" ] && echo "⚠️ Unknown model $model_name for estimation, will use default model ... This will likely produce very unaccurate results!" >> $GITHUB_STEP_SUMMARY
        # we use a default configuration here from https://datavizta.boavizta.org/serversimpact

        add_var "MACHINE_POWER_DATA" "default.sh";

        add_var "SCI_M" 800.3;
        # we use 4 years - 1*60*60*24*365*4 =
        add_var "SCI_USAGE_DURATION" 126144000
        add_var "MODEL_NAME" "unknown";
    elif [[ "$machine_power_data" == "github_EPYC_7763_4_CPU_shared.sh" ]]; then
        echo "Using github_EPYC_7763_4_CPU_shared.sh";

        add_var "MODEL_NAME" "EPYC_7763";
        # FROM https://datavizta.boavizta.org/serversimpact
        # we assume a disk size of 448 GB total.
        # This totals to 1151.7 kg. With a 4/128 splitting this is 35,990.625 gCO2e
        add_var "SCI_M" 35990.625;
        # we use 4 years - 1*60*60*24*365*4 =
        add_var "SCI_USAGE_DURATION" 126144000

    # gitlab uses this one https://docs.gitlab.com/ee/ci/runners/hosted_runners/linux.html (Q1/2024)
    # https://www.green-coding.io/case-studies/cpu-utilization-usefulness/
    elif [[ "$machine_power_data" == "gitlab_EPYC_7B12_saas-linux-small-amd64.sh" ]]; then
        echo "Using gitlab_EPYC_7B12_saas-linux-small-amd64.sh"
        add_var "MODEL_NAME" "EPYC_7B12";
        # we assume a disk size of 1344 GB total according to https://gitlab.com/gitlab-org/gitlab-runner/-/issues/29107
        # which claims runners have 21 GB of disk space with a splitting facttor of 1/64
        # FROM https://datavizta.boavizta.org/serversimpact
        # This totals to 1173.7 kg. With a 1/64 splitting this is 18339,0625 gCO2e
        add_var "SCI_M" 18339.0625;
        # we use 4 years - 1*60*60*24*365*4 =
        add_var "SCI_USAGE_DURATION" 126144000
    fi
}



# Main script logic
if [ $# -eq 0 ]; then
  echo "No option provided. Please specify an option: cpu_vars, read_vars, or add_var [key] [value]."
  exit 1
fi

option="$1"
case $option in
  cpu_vars)
    cpu_vars_fill $2
    ;;
  add_var)
    add_var $2 "$3"
    ;;
  read_vars)
    read_vars
    ;;
  *)
    echo "Invalid option ($option). Please specify an option: cpu_vars, read_vars or add_var [key] [value]."
    exit 1
    ;;
esac