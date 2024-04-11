#!/bin/bash
set -euo pipefail

# Call the function to read and set the variables
source "$(dirname "$0")/vars.sh" read_vars

function make_measurement() {
    # First get values, in case any are unbound
    # this will set them to an empty string if they are missing entirely
    MODEL_NAME=${MODEL_NAME:-}
    TDP=${TDP:-}
    CPU_THREADS=${CPU_THREADS:-}
    CPU_CORES=${CPU_CORES:-}
    CPU_MAKE=${CPU_MAKE:-}
    RELEASE_YEAR=${RELEASE_YEAR:-}
    RAM=${RAM:-}
    CPU_FREQ=${CPU_FREQ:-}
    CPU_CHIPS=${CPU_CHIPS:-}
    VHOST_RATIO=${VHOST_RATIO:-}
    PREVIOUS_VENV=${PREVIOUS_VENV:-}
    MEASUREMENT_COUNT=${MEASUREMENT_COUNT:-}
    WORKFLOW_ID=${WORKFLOW_ID:-}
    API_BASE=${API_BASE:-}

    # check wc -l of cpu-util is greater than 0
    if [[ $(wc -l < /tmp/eco-ci/cpu-util.txt) -gt 0 ]]; then
        # capture time
        time=$(($(date +%s) - $(cat /tmp/eco-ci/timer.txt)))

        # capture cpu util
        cat /tmp/eco-ci/cpu-util.txt > /tmp/eco-ci/cpu-util-temp.txt

        # if a previous venv is already active,
        if type deactivate &>/dev/null
        then
           deactivate
        fi
        # then activate our venv
        source /tmp/eco-ci/venv/bin/activate

        ## make a note that we cannot use --energy, skew the result as we do not have an input delay.
        # this works because demo-reporter is 1/second
        if [[ "$MODEL_NAME" == "unknown" ]]; then
            cat /tmp/eco-ci/cpu-util-temp.txt | python3 /tmp/eco-ci/spec-power-model/xgb.py --silent | tee -a /tmp/eco-ci/energy-total.txt > /tmp/eco-ci/energy.txt
        elif [[ -n "$VHOST_RATIO" ]]; then
            cat /tmp/eco-ci/cpu-util-temp.txt | python3 /tmp/eco-ci/spec-power-model/xgb.py \
            --tdp $TDP --cpu-threads $CPU_THREADS \
            --cpu-cores $CPU_CORES --cpu-make $CPU_MAKE \
            --release-year $RELEASE_YEAR --ram $RAM \
            --cpu-freq $CPU_FREQ --cpu-chips $CPU_CHIPS \
            --vhost-ratio $VHOST_RATIO --silent | tee -a /tmp/eco-ci/energy-total.txt > /tmp/eco-ci/energy.txt
        else
            cat /tmp/eco-ci/cpu-util-temp.txt | python3 /tmp/eco-ci/spec-power-model/xgb.py \
            --tdp $TDP --cpu-threads $CPU_THREADS \
            --cpu-cores $CPU_CORES --cpu-make $CPU_MAKE \
            --release-year $RELEASE_YEAR --ram $RAM \
            --cpu-freq $CPU_FREQ --cpu-chips $CPU_CHIPS \
            --silent | tee -a /tmp/eco-ci/energy-total.txt > /tmp/eco-ci/energy.txt
        fi

        # now reset to old venv
        deactivate
        # reactivate the old venv, if it was present
        if [[ $PREVIOUS_VENV != '' ]]; then
          source $PREVIOUS_VENV/bin/activate
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

        cpu_avg=$(awk '{ total += $1; count++ } END { print total/count }' /tmp/eco-ci/cpu-util-temp.txt)
        total_energy=$(awk '{sum+=$1} END {print sum}' /tmp/eco-ci/energy.txt)
        power_avg=$(awk '{ total += $1; count++ } END { print total/count }' /tmp/eco-ci/energy.txt)

        key_to_add="measurement_"$MEASUREMENT_COUNT
        value_to_add="label:\"$label\", cpu_avg:$cpu_avg, total_energy:$total_energy, power_avg:$power_avg, time:$time"
        source "$(dirname "$0")/vars.sh" add_var $key_to_add "$value_to_add"

        echo $total_energy >> /tmp/eco-ci/energy-values.txt
        source "$(dirname "$0")/vars.sh" add_var MEASUREMENT_RAN true

        if [ -z "$cb_machine_uuid" ]; then
             cb_machine_uuid=$(uuidgen)
        fi

        if [[ $send_data == 'true' ]]; then

            source "$(dirname "$0")/vars.sh" get_co2 "$total_energy"

            add_endpoint=$API_BASE"/v1/ci/measurement/add"
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
                \"duration\":\"$time\",
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
        source "$(dirname "$0")/add-data.sh" --file "${lap_data_file}" --label "$label" --cpu "${cpu_avg}" --energy "${total_energy}" --power "${power_avg}" --time "${time}"

        # reset timer and cpu capturing
        killall -9 -q /tmp/eco-ci/demo-reporter || true
        /tmp/eco-ci/demo-reporter | tee -a /tmp/eco-ci/cpu-util-total.txt > /tmp/eco-ci/cpu-util.txt &
        date +%s > /tmp/eco-ci/timer.txt

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
