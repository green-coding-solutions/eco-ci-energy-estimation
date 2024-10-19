#!/usr/bin/env bash
set -euo pipefail

# Call the function to read and set the variables
source "$(dirname "$0")/vars.sh"
read_vars

function make_inference() {
    BASH_VERSION=${BASH_VERSION:-}
    ECO_CI_MACHINE_POWER_DATA=${ECO_CI_MACHINE_POWER_DATA:-}

    # clear energy file for step because we fill it later anew
    echo > /tmp/eco-ci/energy-step.txt

    # bash mode inference is slower in initi<al reading
    # but 100x faster in reading. The net gain is after ~ 5 measurements
    if [[ -n "$BASH_VERSION" ]] && (( ${BASH_VERSION:0:1} >= 4 )); then
        echo "Using bash mode inference"
        source "$(dirname "$0")/../machine-power-data/${ECO_CI_MACHINE_POWER_DATA}" # will set cloud_energy_hashmap

        while read -r read_var_time read_var_util; do
            echo "${read_var_time} ${cloud_energy_hashmap[$read_var_util]}" | awk '{printf "%.9f\n", $1 * $2}' >> /tmp/eco-ci/energy-step.txt
        done < /tmp/eco-ci/cpu-util-temp.txt
    else
        echo 'Using legacy mode inference'
        while read -r read_var_time read_var_util; do
            # The pattern contains a . and [ ] but this no problem as no other dot appears anywhere
            power_value=$(awk -F "=" -v pattern="cloud_energy_hashmap\\[${read_var_util}\\]" ' $0 ~ pattern { print $2 }' $ECO_CI_MACHINE_POWER_DATA)
            echo "${read_var_time} ${power_value}" | awk '{printf "%.9f\n", $1 * $2}' >> /tmp/eco-ci/energy-step.txt
        done < /tmp/eco-ci/cpu-util-temp.txt
    fi
}

function make_measurement() {
    label="$1"

    # First get values, in case any are unbound
    # this will set them to an empty string if they are missing entirely
    ECO_CI_MODEL_NAME=${ECO_CI_MODEL_NAME:-}
    ECO_CI_MEASUREMENT_COUNT=${ECO_CI_MEASUREMENT_COUNT:-}
    ECO_CI_WORKFLOW_ID=${ECO_CI_WORKFLOW_ID:-}

    # capture time - Note that we need 64 bit here!
    step_time_us=$(($(date "+%s%6N") - $(cat /tmp/eco-ci/timer-step.txt)))
    step_time_s=$(echo "$step_time_us 1000000" | awk '{printf "%.2f", $1 / $2}')

    # Capture current cpu util file and trim trailing empty lines from the file to not run into read/write race condition later
    sed '/^[[:space:]]*$/d' /tmp/eco-ci/cpu-util-step.txt > /tmp/eco-ci/cpu-util-temp.txt

    # check wc -l of cpu-util is greater than 0
    if [[ $(wc -l < /tmp/eco-ci/cpu-util-temp.txt) -gt 0 ]]; then
        make_inference # will populate /tmp/eco-ci/energy-step.txt

        if [[ -z $ECO_CI_MEASUREMENT_COUNT ]]; then
            ECO_CI_MEASUREMENT_COUNT=1
            add_var 'ECO_CI_MEASUREMENT_COUNT' $ECO_CI_MEASUREMENT_COUNT
        else
            ECO_CI_MEASUREMENT_COUNT=$((ECO_CI_MEASUREMENT_COUNT+1))
            add_var 'ECO_CI_MEASUREMENT_COUNT' $ECO_CI_MEASUREMENT_COUNT
        fi

        if [[ -z $label ]]; then
            label="Measurement #${ECO_CI_MEASUREMENT_COUNT}"
        fi

        cpu_avg=$(awk '{ total += $2; count++ } END { print total/count }' /tmp/eco-ci/cpu-util-temp.txt)
        step_energy=$(awk '{sum+=$1} END {print sum}' /tmp/eco-ci/energy-step.txt)
        power_avg=$(echo "$step_energy $step_time_s" | awk '{printf "%.2f", $1 / $2}')

        add_var "ECO_CI_MEASUREMENT_${ECO_CI_MEASUREMENT_COUNT}_LABEL" "$label"
        add_var "ECO_CI_MEASUREMENT_${ECO_CI_MEASUREMENT_COUNT}_CPU_AVG" "$cpu_avg"
        add_var "ECO_CI_MEASUREMENT_${ECO_CI_MEASUREMENT_COUNT}_ENERGY" "$step_energy"
        add_var "ECO_CI_MEASUREMENT_${ECO_CI_MEASUREMENT_COUNT}_POWER_AVG" "$power_avg"
        add_var "ECO_CI_MEASUREMENT_${ECO_CI_MEASUREMENT_COUNT}_TIME" "$step_time_s"

        echo $step_energy >> /tmp/eco-ci/energy-values.txt


        if [[ "$ECO_CI_SEND_DATA" == 'true' ]]; then
            echo "Sending data to ${ECO_CI_API_ENDPOINT_ADD}"

            source "$(dirname "$0")/misc.sh"
            get_energy_co2 "$step_energy"
            get_embodied_co2 "$step_time_s"
            read_vars # reload set vars

            # CO2 API might have failed or not set, so we only calculate total if it worked
            ECO_CI_CO2EQ_EMBODIED=${ECO_CI_CO2EQ_EMBODIED:-}  # Default to an empty string if unset
            ECO_CI_CO2EQ_ENERGY=${ECO_CI_CO2EQ_ENERGY:-}      # Default to an empty string if unset

            if [ -n "$ECO_CI_CO2EQ_EMBODIED" ] && [ -n "$ECO_CI_CO2EQ_ENERGY" ]; then # We only check for co2 as if this is set the others should be set too
                carbon_ug=$(echo "${ECO_CI_CO2EQ_EMBODIED} ${ECO_CI_CO2EQ_ENERGY} 1000000" | awk '{printf "%d", ($1 + $2) * $3 }')
            else
                carbon_ug='null'
            fi

            energy_uj=$(echo "${step_energy} 1000000" | awk '{printf "%d", $1 * $2}' | cut -d '.' -f 1)

            model_name_uri=$(echo $ECO_CI_MODEL_NAME | jq -Rr @uri)

            tags_as_json_list=''
            if [[ "$ECO_CI_FILTER_TAGS" != '' ]]; then # prevent sending [""] array if empty
              tags_as_json_list=$(echo "\"${ECO_CI_FILTER_TAGS}\"" | sed s/,/\",\"/g)
            fi


            curl -X POST "${ECO_CI_API_ENDPOINT_ADD}" \
                -H 'Content-Type: application/json' \
                -H "X-Authentication: ${ECO_CI_API_AUTHENTICATION_TOKEN}" \
                -d "{
                \"energy_uj\":\"${energy_uj}\",
                \"cpu\":\"${model_name_uri}\",
                \"commit_hash\":\"${ECO_CI_COMMIT_HASH}\",
                \"repo\":\"${ECO_CI_REPOSITORY}\",
                \"branch\":\"${ECO_CI_BRANCH}\",
                \"workflow\":\"${ECO_CI_WORKFLOW_ID}\",
                \"run_id\":\"${ECO_CI_RUN_ID}\",
                \"label\":\"${label}\",
                \"source\":\"${ECO_CI_SOURCE}\",
                \"cpu_util_avg\":\"${cpu_avg}\",
                \"duration_us\":\"${step_time_us}\",
                \"workflow_name\":\"${ECO_CI_WORKFLOW_NAME}\",
                \"filter_type\":\"${ECO_CI_FILTER_TYPE}\",
                \"filter_project\":\"${ECO_CI_FILTER_PROJECT}\",
                \"filter_machine\":\"${ECO_CI_FILTER_MACHINE}\",
                \"filter_tags\":[${tags_as_json_list}],
                \"lat\":\"${ECO_CI_LAT:-""}\",
                \"lon\":\"${ECO_CI_LON:-""}\",
                \"city\":\"${ECO_CI_CITY:-""}\",
                \"carbon_intensity_g\":${ECO_CI_CO2I:-"null"},
                \"carbon_ug\":${carbon_ug}
            }"
        fi

        if [[ ${ECO_CI_JSON_OUTPUT} == 'true' ]]; then
            lap_data_file='/tmp/eco-ci/lap-data.json'
            echo 'show create-and-add-meta.sh output'
            source "$(dirname "$0")/create-and-add-meta.sh" create_json_file "${lap_data_file}"
            source "$(dirname "$0")/add-data.sh" create_json_file "${lap_data_file}" "${label}" "${cpu_avg}" "${step_energy}" "${power_avg}" "${step_time_s}"
        fi

        # merge all current data to the totals file. This means we will include the overhead since we do it AFTER this processing block
        sed '/^[[:space:]]*$/d' /tmp/eco-ci/cpu-util-step.txt >> /tmp/eco-ci/cpu-util-total.txt
        sed '/^[[:space:]]*$/d' /tmp/eco-ci/energy-step.txt >> /tmp/eco-ci/energy-total.txt

        # Reset the step timers, so we do not capture the overhead per step
        # we want to only caputure the overhead in the totals
        source "$(dirname "$0")/setup.sh" lap_measurement

    else
        echo "Skipping measurement as no data was collected since last call"
    fi
 }


option="$1"
case $option in
  make_inference)
    make_inference
    ;;
  make_measurement)
    make_measurement "$2"
    ;;
esac
