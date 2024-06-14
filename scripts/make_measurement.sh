#!/usr/bin/env bash
set -euo pipefail

# Call the function to read and set the variables
source "$(dirname "$0")/vars.sh" read_vars

function make_measurement() {
    # First get values, in case any are unbound
    # this will set them to an empty string if they are missing entirely
    MODEL_NAME=${MODEL_NAME:-}
    MEASUREMENT_COUNT=${MEASUREMENT_COUNT:-}
    WORKFLOW_ID=${WORKFLOW_ID:-}
    DASHBOARD_API_BASE=${DASHBOARD_API_BASE:-}
    MACHINE_POWER_DATA=${MACHINE_POWER_DATA:-}

    # capture time
    step_time=$(($(date +%s) - $(cat /tmp/eco-ci/timer-step.txt)))

    # reset timer and cpu capturing (lap)
    source "$(dirname "$0")/setup.sh" lap_measurement

    # capture cpu util so we have a file that is currently not written to
    cat /tmp/eco-ci/cpu-util-step.txt > /tmp/eco-ci/cpu-util-temp.txt

    # clear energy file for step
    echo > /tmp/eco-ci/energy-step.txt


    # check wc -l of cpu-util is greater than 0
    if [[ $(wc -l < /tmp/eco-ci/cpu-util-temp.txt) -gt 0 ]]; then

        # bash mode inference is slower in initial reading
        # but 100x faster in reading. The net gain is after ~ 5 measurements
        if [[ -n "$BASH_VERSION" ]] && (( ${BASH_VERSION:0:1} >= 4 )); then
            echo "Using bash mode inference"
            source "$(dirname "$0")/../machine-power-data/${MACHINE_POWER_DATA}" # will set cloud_energy_hashmap

            while read -r read_var_time read_var_util; do
                echo "$read_var_time * $read_var_util"
                echo ${cloud_energy_hashmap[$read_var_util]}
                echo "$read_var_time * ${cloud_energy_hashmap[$read_var_util]}" | bc -l >> /tmp/eco-ci/energy-step.txt
            done < /tmp/eco-ci/cpu-util-temp.txt
        else
            echo "Using legacy mode inference"
            while read -r read_var_time read_var_util; do
                # The pattern contains a . and [ ] but this no problem as no other dot appears anywhere
                power_value=$(awk -F "=" -v pattern="cloud_energy_hashmap[$read_var_util]" ' 0 ~ pattern { print $2 }' $MACHINE_POWER_DATA)
                echo "$read_var_time * ${power_value}" | bc -l >> /tmp/eco-ci/energy-step.txt
            done < /tmp/eco-ci/cpu-util-temp.txt
        fi

        if [[ $MEASUREMENT_COUNT == '' ]]; then
            MEASUREMENT_COUNT=1
            source "$(dirname "$0")/vars.sh" add_var MEASUREMENT_COUNT $MEASUREMENT_COUNT
        else
            MEASUREMENT_COUNT=$((MEASUREMENT_COUNT+1))
            source "$(dirname "$0")/vars.sh" add_var MEASUREMENT_COUNT $MEASUREMENT_COUNT
        fi

        if [[ $label == '' ]]; then
            label="Measurement #$MEASUREMENT_COUNT"
        fi

        cpu_avg=$(awk '{ total += $2; count++ } END { print total/count }' /tmp/eco-ci/cpu-util-temp.txt)
        total_energy=$(awk '{sum+=$1} END {print sum}' /tmp/eco-ci/energy-step.txt)
        power_avg=$(awk '{ total += $1; count++ } END { print total/count }' /tmp/eco-ci/energy-step.txt)

        source "$(dirname "$0")/vars.sh" add_var "MEASUREMENT_${MEASUREMENT_COUNT}_LABEL" "$label"
        source "$(dirname "$0")/vars.sh" add_var "MEASUREMENT_${MEASUREMENT_COUNT}_CPU_AVG" "$cpu_avg"
        source "$(dirname "$0")/vars.sh" add_var "MEASUREMENT_${MEASUREMENT_COUNT}_TOTAL_ENERGY" "$total_energy"
        source "$(dirname "$0")/vars.sh" add_var "MEASUREMENT_${MEASUREMENT_COUNT}_POWER_AVG" "$power_avg"
        source "$(dirname "$0")/vars.sh" add_var "MEASUREMENT_${MEASUREMENT_COUNT}_TIME" "$step_time"

        echo $total_energy >> /tmp/eco-ci/energy-values.txt

        if [[ $send_data == 'true' ]]; then

            source "$(dirname "$0")/misc.sh" get_energy_co2 "$total_energy"
            source "$(dirname "$0")/misc.sh" get_embodied_co2 "$step_time"

            CO2EQ=$(echo "$CO2EQ_EMBODIED +  $CO2EQ_ENERGY" | bc -l)

            add_endpoint=$DASHBOARD_API_BASE"/v1/ci/measurement/add"
            value_mJ=$(echo "$total_energy*1000" | bc -l | cut -d '.' -f 1)
            unit="mJ"
            model_name_uri=$(echo $MODEL_NAME | jq -Rr @uri)

            curl -X POST "$add_endpoint" -H 'Content-Type: application/json' -d "{
                \"energy_value\":\"$value_mJ\",
                \"energy_unit\":\"$unit\",
                \"cpu\":\"$model_name_uri\",
                \"commit_hash\":\"${commit_hash}\",
                \"repo\":\"${repo}\",
                \"branch\":\"${branch}\",
                \"workflow\":\"$WORKFLOW_ID\",
                \"run_id\":\"${run_id}\",
                \"project_id\":\"\",
                \"label\":\"$label\",
                \"source\":\"$source\",
                \"cpu_util_avg\":\"$cpu_avg\",
                \"duration\":\"$step_time\",
                \"workflow_name\":\"$workflow_name\",
                \"cb_company_uuid\":\"$cb_company_uuid\",
                \"cb_project_uuid\":\"$cb_project_uuid\",
                \"cb_machine_uuid\":\"$cb_machine_uuid\",
                \"lat\":\"${LAT:-""}\",
                \"lon\":\"${LON:-""}\",
                \"city\":\"${CITY:-""}\",
                \"co2i\":\"${CO2I:-""}\",
                \"co2eq\":\"${CO2EQ:-""}\"
            }"
        fi

        # write data to output
        lap_data_file="/tmp/eco-ci/lap-data.json"
        repo_enc=$( echo ${repo} | jq -Rr @uri)
        branch_enc=$( echo $branch | jq -Rr @uri)
        run_id_enc=$( echo ${run_id} | jq -Rr @uri)

        echo "show create-and-add-meta.sh output"
        echo "--file $lap_data_file --repository $repo_enc --branch $branch_enc --workflow $WORKFLOW_ID --run_id $run_id_enc"

        source "$(dirname "$0")/create-and-add-meta.sh" --file "${lap_data_file}" --repository "${repo_enc}" --branch "${branch_enc}" --workflow "$WORKFLOW_ID" --run_id "${run_id_enc}"
        source "$(dirname "$0")/add-data.sh" --file "${lap_data_file}" --label "$label" --cpu "${cpu_avg}" --energy "${total_energy}" --power "${power_avg}" --time "${step_time}"

        # Reset the timers again, so we do not capture the overhead per step
        # we want to only caputure the overhead in the totals
        source "$(dirname "$0")/setup.sh" lap_measurement

    else
        echo "Skipping measurement as no data was collected since last call"
    fi
 }

label=""
run_id=""
branch=""
repo=""
commit_hash=""
send_data=""
source=""
cb_company_uuid=""
cb_project_uuid=""
cb_machine_uuid=""

while [[ $# -gt 0 ]]; do
    opt="$1"

    case $opt in
        -l|--label)
        label="$2"
        shift
        ;;
        -r|--run-id)
        run_id="$2"
        shift
        ;;
        -b|--branch)
        branch="$2"
        shift
        ;;
        -R|--repo)
        repo="$2"
        shift
        ;;
        -c|--commit)
        commit_hash="$2"
        shift
        ;;
        -sd|--send-data)
        send_data="$2"
        shift
        ;;
        -s|--source)
        source="$2"
        shift
        ;;
        -n|--name)
        workflow_name="$2"
        shift
        ;;
        -cbc|--carbondbcompany)
        cb_company_uuid="$2"
        shift
        ;;
        -cbp|--carbondbproject)
        cb_project_uuid="$2"
        shift
        ;;
        -cbm|--carbondbmachine)
        cb_machine_uuid="$2"
        shift
        ;;
        *)
        echo "Invalid option -$opt" >&2
        exit 1
        ;;
    esac
    shift
done

make_measurement
