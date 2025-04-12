#!/usr/bin/env bash
set -euo pipefail

# Call the function to read and set the variables
source "$(dirname "$0")/vars.sh"
read_vars

function make_inference_single() {
    local utilization=$1
    local power_data_file_path="$(dirname "$0")/../machine-power-data/${ECO_CI_MACHINE_POWER_DATA}"
        source "${power_data_file_path}" # will set cloud_energy_hashmap

    if [[ -n "$BASH_VERSION" ]] && (( ${BASH_VERSION:0:1} >= 4 )); then
        echo ${cloud_energy_hashmap[$utilization]} # will be return
    else
        echo 'Using legacy mode inference'
        # The pattern contains a . and [ ] but this no problem as no other dot appears anywhere
        local power_value=$(awk -F "=" -v pattern="cloud_energy_hashmap\\\\[${read_var_util}\\\\]" ' $0 ~ pattern { print $2 }' "${power_data_file_path}")

        if [[ -z $power_value ]]; then
            echo "Could not match power value for utilization: '${read_var_util}'" >&2
            exit -1
        fi
        echo $power_value # will be return
    fi

}

function make_inference() {
    # First get values, in case any are unbound
    # this will set them to an empty string if they are missing entirely
    BASH_VERSION=${BASH_VERSION:-}
    GITHUB_STEP_SUMMARY=${GITHUB_STEP_SUMMARY:-}

    # clear energy file for step because we fill it later anew
    echo > /tmp/eco-ci/energy-step.txt

    local power_data_file_path="$(dirname "$0")/../machine-power-data/${ECO_CI_MACHINE_POWER_DATA}"
    local read_var_time
    local read_var_util

    # bash mode inference is slower in initi<al reading
    # but 100x faster in reading. The net gain is after ~ 5 measurements
    if [[ -n "$BASH_VERSION" ]] && (( ${BASH_VERSION:0:1} >= 4 )); then
        echo "Using bash mode inference"
        source "${power_data_file_path}" # will set cloud_energy_hashmap

        while read -r read_var_time read_var_util; do
            echo "${read_var_time} ${cloud_energy_hashmap[$read_var_util]}" | awk '{printf "%.9f\n", $1 * $2}' >> /tmp/eco-ci/energy-step.txt
        done < /tmp/eco-ci/cpu-util-temp.txt
    else
        echo 'Using legacy mode inference'
        local power_value
        while read -r read_var_time read_var_util; do
            # The pattern contains a . and [ ] but this no problem as no other dot appears anywhere

            power_value=$(awk -F "=" -v pattern="cloud_energy_hashmap\\\\[${read_var_util}\\\\]" ' $0 ~ pattern { print $2 }' "${power_data_file_path}")

            if [[ -z $power_value ]]; then
                echo "Could not match power value for utilization: '${read_var_util}'" >&2
                exit -1
            fi

            echo "${read_var_time} ${power_value}" | awk '{printf "%.9f\n", $1 * $2}' >> /tmp/eco-ci/energy-step.txt
        done < /tmp/eco-ci/cpu-util-temp.txt
    fi
}

function make_measurement() {
    local label="$1"

    # First get values, in case any are unbound
    # this will set them to an empty string if they are missing entirely
    ECO_CI_MODEL_NAME=${ECO_CI_MODEL_NAME:-}
    ECO_CI_MEASUREMENT_COUNT=${ECO_CI_MEASUREMENT_COUNT:-}
    ECO_CI_WORKFLOW_ID=${ECO_CI_WORKFLOW_ID:-}
    ECO_CI_STEP_NOTE=''

    # capture time - Note that we need 64 bit here!
    local step_time_us=$(($(date "+%s%6N") - $(cat /tmp/eco-ci/timer-step.txt)))

    # Capture current cpu util file and trim trailing empty lines from the file to not run into read/write race condition later
    sed '/^[[:space:]]*$/d' /tmp/eco-ci/cpu-util-step.txt > /tmp/eco-ci/cpu-util-temp.txt

    # check wc -l of cpu-util is greater than 0
    local captured_datapoints=$(wc -l < /tmp/eco-ci/cpu-util-temp.txt)
    local current_step_captured_duration=$(awk '{sum+=$1} END {print sum}' /tmp/eco-ci/cpu-util-temp.txt)

    # calculate step times now. not earlier. to make all calculations after all capturing
    read step_time_s step_time_s_int step_time_difference <<<  $(echo "$step_time_us 1000000 $current_step_captured_duration" | awk '{printf "%.2f %d %.9f", $1 / $2, int($1 / $2), ($1 / $2) - $3}')

    if [[ $captured_datapoints -gt 0 ]]; then
        if [[ $captured_datapoints -lt $(($step_time_s_int - 1)) ]]; then # one datapoint might be missing due to the fact that we need to wait for one tick
            ECO_CI_STEP_NOTE="Missing data points. Expected ${step_time_s_int} (-1) but got ${captured_datapoints}"
            echo "Error! - " $ECO_CI_STEP_NOTE  >&2
            [ -n "$GITHUB_STEP_SUMMARY" ] && echo "❌ Error! - $ECO_CI_STEP_NOTE" >> $GITHUB_STEP_SUMMARY
        fi

        # now we are backfilling data. this happens in any case as due to the low sampling rate of 1 seconds we will have
        # up to 0.99s of missing data. We backfill by replicating the last line of cpu-util-temp with the same value for the missing amount of time
        read _ last_line_cpu_tmp_utilization <<< "$(tail -n 1 /tmp/eco-ci/cpu-util-temp.txt)"
        echo "${step_time_difference} ${last_line_cpu_tmp_utilization}" >> /tmp/eco-ci/cpu-util-temp.txt
        echo 'Backfilling ' $step_time_difference 's in step with ' $last_line_cpu_tmp_utilization

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


        local cpu_avg=$(awk '{ total += $2; count++ } END { print total/count }' /tmp/eco-ci/cpu-util-temp.txt)
        local step_energy=$(awk '{sum+=$1} END {print sum}' /tmp/eco-ci/energy-step.txt)
        local power_avg=$(echo "$step_energy $step_time_s" | awk '{printf "%.2f", $1 / $2}')

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
                local carbon_ug=$(echo "${ECO_CI_CO2EQ_EMBODIED} ${ECO_CI_CO2EQ_ENERGY} 1000000" | awk '{printf "%d", ($1 + $2) * $3 }')
            else
                local carbon_ug='null'
            fi

            local energy_uj=$(echo "${step_energy} 1000000" | awk '{printf "%d", $1 * $2}' | cut -d '.' -f 1)

            local tags_as_json_list=''
            if [[ "$ECO_CI_FILTER_TAGS" != '' ]]; then # prevent sending [""] array if empty
              tags_as_json_list=$(echo  $ECO_CI_FILTER_TAGS | jq -Rr @json | sed 's/,/\",\"/g' )
            fi


            # Important: The data is NOT escaped! Since we control all variables locally we must make sure that no crap values are in there
            # like unescaped " for instance
            local curl_response=$(curl -w "%{http_code}" -X POST "${ECO_CI_API_ENDPOINT_ADD}" \
                -H 'Content-Type: application/json' \
                -H "X-Authentication: ${ECO_CI_GMT_API_TOKEN}" \
                -d "{
                \"energy_uj\":\"${energy_uj}\",
                \"cpu\": $(echo $ECO_CI_MODEL_NAME | jq -Rr @json),
                \"commit_hash\":\"${ECO_CI_COMMIT_HASH}\",
                \"repo\":\"${ECO_CI_REPOSITORY}\",
                \"branch\":\"${ECO_CI_BRANCH}\",
                \"workflow\":\"${ECO_CI_WORKFLOW_ID}\",
                \"run_id\":\"${ECO_CI_RUN_ID}\",
                \"label\": $(echo $label | jq -Rr @json),
                \"source\":\"${ECO_CI_SOURCE}\",
                \"cpu_util_avg\":\"${cpu_avg}\",
                \"duration_us\":\"${step_time_us}\",
                \"workflow_name\": $(echo $ECO_CI_WORKFLOW_NAME | jq -Rr @json),
                \"filter_type\": $(echo $ECO_CI_FILTER_TYPE | jq -Rr @json),
                \"filter_project\": $(echo $ECO_CI_FILTER_PROJECT | jq -Rr @json) ,
                \"filter_machine\": $(echo $ECO_CI_FILTER_MACHINE | jq -Rr @json),
                \"filter_tags\":[${tags_as_json_list}],
                \"lat\":\"${ECO_CI_GEO_LAT:-""}\",
                \"lon\":\"${ECO_CI_GEO_LON:-""}\",
                \"city\":\"${ECO_CI_GEO_CITY:-""}\",
                \"ip\":\"${ECO_CI_GEO_IP:-""}\",
                \"carbon_intensity_g\":${ECO_CI_CO2I:-"null"},
                \"carbon_ug\":${carbon_ug},
                \"note\":  $(echo $ECO_CI_STEP_NOTE | jq -Rr @json)
            }" 2>&1 || true)

            local http_code=$(echo "$curl_response" | tail -n 1)

            if [[ "$http_code" != "204" ]]; then
                echo "Error! - Could not send data to GMT API: $curl_response" >&2
                [ -n "$GITHUB_STEP_SUMMARY" ] && echo "❌ Error! - Could not send data to GMT API: $curl_response" >> $GITHUB_STEP_SUMMARY
            fi

        fi

        if [[ ${ECO_CI_JSON_OUTPUT} == 'true' ]]; then
            local lap_data_file='/tmp/eco-ci/lap-data.json'
            echo 'show create-and-add-meta.sh output'
            source "$(dirname "$0")/create-and-add-meta.sh" create_json_file "${lap_data_file}"
            source "$(dirname "$0")/add-data.sh" create_json_file "${lap_data_file}" "${label}" "${cpu_avg}" "${step_energy}" "${power_avg}" "${step_time_s}"
        fi

        # merge all current data to the totals file. This means we will include the overhead since we do it AFTER this processing block
        # this block may well take longer than one second, as we also have API requests in there and thus cpu-uti-step might have accumulated
        # more rows than when we captured it earlier
        sed '/^[[:space:]]*$/d' /tmp/eco-ci/cpu-util-temp.txt >> /tmp/eco-ci/cpu-util-total.txt # we must take util-tmp here, as this is already backfilled
        sed '/^[[:space:]]*$/d' /tmp/eco-ci/energy-step.txt >> /tmp/eco-ci/energy-total.txt # energy-step is also already backfilled, so overhead is now only our code

        local step_time_total_us=$(($(date "+%s%6N") - $(cat /tmp/eco-ci/timer-total.txt)))
        local step_time_total_s=$(echo "$step_time_total_us 1000000" | awk '{printf "%.9f", $1 / $2}')
        local all_steps_captured_duration=$(awk '{sum+=$1} END {print sum}' /tmp/eco-ci/cpu-util-total.txt)

        # calculate step times now. not earlier. to make all calculations after all capturing
        local overhead_step_time_difference=$(echo "${step_time_total_s} ${all_steps_captured_duration}" | awk '{printf "%.9f", $1 - $2}')

        local last_line_cpu_total_utilization
        read _ last_line_cpu_total_utilization <<< "$(tail -n 1 /tmp/eco-ci/cpu-util-total.txt)"
        echo "${overhead_step_time_difference} ${last_line_cpu_total_utilization}" >> /tmp/eco-ci/cpu-util-total.txt
        echo 'Backfilling ' $overhead_step_time_difference 's in cpu-util-total with ' $last_line_cpu_total_utilization

        local extrapolated_energy_total=$(make_inference_single $last_line_cpu_total_utilization)
        echo "${overhead_step_time_difference} ${extrapolated_energy_total}" | awk '{printf "%.9f\n", $1 * $2}' >> /tmp/eco-ci/energy-total.txt
        echo 'Backfilling ' $overhead_step_time_difference 's in energy-total with ' $extrapolated_energy_total

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
