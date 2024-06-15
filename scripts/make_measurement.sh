#!/usr/bin/env bash
set -euo pipefail

# Call the function to read and set the variables
source "$(dirname "$0")/vars.sh"
read_vars

function make_inference() {
    BASH_VERSION=${BASH_VERSION:-}
    MACHINE_POWER_DATA=${MACHINE_POWER_DATA:-}

    # clear energy file for step because we fill it later anew
    echo > /tmp/eco-ci/energy-step.txt

    # bash mode inference is slower in initi<al reading
    # but 100x faster in reading. The net gain is after ~ 5 measurements
    if [[ -n "$BASH_VERSION" ]] && (( ${BASH_VERSION:0:1} >= 4 )); then
        echo "Using bash mode inference"
        source "$(dirname "$0")/../machine-power-data/${MACHINE_POWER_DATA}" # will set cloud_energy_hashmap

        while read -r read_var_time read_var_util; do
            echo "$read_var_time ${cloud_energy_hashmap[$read_var_util]}" | awk '{printf "%.9f\n", $1 * $2}' >> /tmp/eco-ci/energy-step.txt
        done < /tmp/eco-ci/cpu-util-temp.txt
    else
        echo "Using legacy mode inference"
        while read -r read_var_time read_var_util; do
            # The pattern contains a . and [ ] but this no problem as no other dot appears anywhere
            power_value=$(awk -F "=" -v pattern="cloud_energy_hashmap[$read_var_util]" ' 0 ~ pattern { print $2 }' $MACHINE_POWER_DATA)
            echo "$read_var_time ${power_value}" | awk '{printf "%.9f\n", $1 * $2}' >> /tmp/eco-ci/energy-step.txt
        done < /tmp/eco-ci/cpu-util-temp.txt
    fi
}

function make_measurement() {
    label="$1"

    # First get values, in case any are unbound
    # this will set them to an empty string if they are missing entirely
    MODEL_NAME=${MODEL_NAME:-}
    MEASUREMENT_COUNT=${MEASUREMENT_COUNT:-}
    WORKFLOW_ID=${WORKFLOW_ID:-}
    DASHBOARD_API_BASE=${DASHBOARD_API_BASE:-}

    # capture time
    step_time=$(($(date +%s) - $(cat /tmp/eco-ci/timer-step.txt)))

    # Capture current cpu util file and trim trailing empty lines from the file to not run into read/write race condition later
    sed '/^[[:space:]]*$/d' /tmp/eco-ci/cpu-util-step.txt > /tmp/eco-ci/cpu-util-temp.txt

    # check wc -l of cpu-util is greater than 0
    if [[ $(wc -l < /tmp/eco-ci/cpu-util-temp.txt) -gt 0 ]]; then
        make_inference # will populate /tmp/eco-ci/energy-step.txt

        if [[ $MEASUREMENT_COUNT == '' ]]; then
            MEASUREMENT_COUNT=1
            add_var MEASUREMENT_COUNT $MEASUREMENT_COUNT
        else
            MEASUREMENT_COUNT=$((MEASUREMENT_COUNT+1))
            add_var MEASUREMENT_COUNT $MEASUREMENT_COUNT
        fi

        if [[ $label == '' ]]; then
            label="Measurement #$MEASUREMENT_COUNT"
        fi

        cpu_avg=$(awk '{ total += $2; count++ } END { print total/count }' /tmp/eco-ci/cpu-util-temp.txt)
        step_energy=$(awk '{sum+=$1} END {print sum}' /tmp/eco-ci/energy-step.txt)
        power_avg=$(echo "$step_energy $step_time" | awk '{printf "%.2f", $1 / $2}')

        add_var "MEASUREMENT_${MEASUREMENT_COUNT}_LABEL" "$label"
        add_var "MEASUREMENT_${MEASUREMENT_COUNT}_CPU_AVG" "$cpu_avg"
        add_var "MEASUREMENT_${MEASUREMENT_COUNT}_ENERGY" "$step_energy"
        add_var "MEASUREMENT_${MEASUREMENT_COUNT}_POWER_AVG" "$power_avg"
        add_var "MEASUREMENT_${MEASUREMENT_COUNT}_TIME" "$step_time"

        echo $step_energy >> /tmp/eco-ci/energy-values.txt


        if [[ $SEND_DATA == 'true' ]]; then

            source "$(dirname "$0")/misc.sh"
            get_energy_co2 "$step_energy"
            get_embodied_co2 "$step_time"
            read_vars # reload set vars

            # CO2 API might have failed or not set, so we only calculate total if it worked
            CO2EQ_EMBODIED=${CO2EQ_EMBODIED:-}  # Default to an empty string if unset
            CO2EQ_ENERGY=${CO2EQ_ENERGY:-}      # Default to an empty string if unset

            if [ -n "$CO2EQ_EMBODIED" ] && [ -n "$CO2EQ_ENERGY" ]; then # We only check for co2 as if this is set the others should be set too
                CO2EQ=$(echo "$CO2EQ_EMBODIED $CO2EQ_ENERGY" | awk '{printf "%.9f", $1 + $2}')
            fi

            add_endpoint=$DASHBOARD_API_BASE"/v1/ci/measurement/add"
            value_mJ=$(echo "$step_energy 1000" | awk '{printf "%.9f", $1 * $2}' | cut -d '.' -f 1)
            unit="mJ"
            model_name_uri=$(echo $MODEL_NAME | jq -Rr @uri)

            curl -X POST "$add_endpoint" -H 'Content-Type: application/json' -d "{
                \"energy_value\":\"$value_mJ\",
                \"energy_unit\":\"$unit\",
                \"cpu\":\"$model_name_uri\",
                \"commit_hash\":\"${COMMIT_HASH}\",
                \"repo\":\"${REPOSITORY}\",
                \"branch\":\"${BRANCH}\",
                \"workflow\":\"$WORKFLOW_ID\",
                \"run_id\":\"${RUN_ID}\",
                \"project_id\":\"\",
                \"label\":\"$label\",
                \"source\":\"$SOURCE\",
                \"cpu_util_avg\":\"$cpu_avg\",
                \"duration\":\"$step_time\",
                \"workflow_name\":\"$WORKFLOW_NAME\",
                \"cb_company_uuid\":\"$CB_COMPANY_UUID\",
                \"cb_project_uuid\":\"$CB_PROJECT_UUID\",
                \"cb_machine_uuid\":\"$CB_MACHINE_UUID\",
                \"lat\":\"${LAT:-""}\",
                \"lon\":\"${LON:-""}\",
                \"city\":\"${CITY:-""}\",
                \"co2i\":\"${CO2I:-""}\",
                \"co2eq\":\"${CO2EQ:-""}\"
            }"
        fi

        if [[ ${JSON_OUTPUT} == 'true' ]]; then
            lap_data_file="/tmp/eco-ci/lap-data.json"
            echo "show create-and-add-meta.sh output"
            source "$(dirname "$0")/create-and-add-meta.sh" create_json_file "${lap_data_file}"
            source "$(dirname "$0")/add-data.sh" create_json_file "${lap_data_file}" "${label}" "${cpu_avg}" "${step_energy}" "${power_avg}" "${step_time}"
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
