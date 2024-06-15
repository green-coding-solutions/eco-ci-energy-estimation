#!/usr/bin/env bash
set -euo pipefail

# Call the function to read and set the variables
source "$(dirname "$0")/vars.sh"
read_vars

function display_results {
    display_table="$1"
    display_badge="$2"

    # First get values, in case any are unbound
    # this will set them to an empty string if they are missing entirely
    MEASUREMENT_RAN=${MEASUREMENT_RAN:-}
    MEASUREMENT_COUNT=${MEASUREMENT_COUNT:-}
    WORKFLOW_ID=${WORKFLOW_ID:-}
    DASHBOARD_API_BASE=${DASHBOARD_API_BASE:-}
    JSON_OUTPUT=${JSON_OUTPUT:-}
    GITHUB_STEP_SUMMARY=${GITHUB_STEP_SUMMARY:-}

    output="/tmp/eco-ci/output.txt"
    output_pr="/tmp/eco-ci/output-pr.txt"

    if [[ $(wc -l < /tmp/eco-ci/energy-total.txt) -eq 0 ]]; then
        echo "Could not display table as no measurement data was present!"
        [ -n "$GITHUB_STEP_SUMMARY" ] && echo "❌ Could not display table as no measurement data was present!" >> $GITHUB_STEP_SUMMARY
        return 1
    fi

    # TODO: Hier müsste ich eigentlich mal stop measurement machen!!!!
    # Und die Overheads von Energy auch richtig kalkulieren!
    # und power_acc ist doppelt! hier kann ich auch total_energy nehmen

    cpu_avg=$(awk '{ total += $2; count++ } END { print total/count }' /tmp/eco-ci/cpu-util-total.txt)
    total_energy=$(awk '{sum+=$1} END {print sum}' /tmp/eco-ci/energy-total.txt)
    total_time=$(($(date +%s) - $(cat /tmp/eco-ci/timer-total.txt)))
    power_avg=$(echo "$total_energy $total_time" | awk '{printf "%.2f", $1 / $2}')

    ## Gitlab Specific Output
    if [[ $SOURCE == 'gitlab' ]]; then
        echo "\"$CI_JOB_NAME: Energy [Joules]:\" $total_energy" | tee -a $output metrics.txt
        echo "\"$CI_JOB_NAME: Avg. CPU Utilization:\" $cpu_avg" | tee -a $output metrics.txt
        echo "\"$CI_JOB_NAME: Avg. Power [Watts]:\" $power_avg" | tee -a $output metrics.txt
        echo "\"$CI_JOB_NAME: Duration [seconds]:\" $total_time" | tee -a $output metrics.txt
        echo "----------------" >> $output

        for (( i=1; i<=$MEASUREMENT_COUNT; i++ )); do
            echo "\"${CI_JOB_NAME}: Label: $(eval echo \$MEASUREMENT_${i}_LABEL): Energy Used [Joules]:\" $(eval echo \$MEASUREMENT_${i}_ENERGY)" | tee -a $output metrics.txt
            echo "\"${CI_JOB_NAME}: Label: $(eval echo \$MEASUREMENT_${i}_LABEL): Avg. CPU Utilization:\" $(eval echo \$MEASUREMENT_${i}_CPU_AVG)" | tee -a $output metrics.txt
            echo "\"${CI_JOB_NAME}: Label: $(eval echo \$MEASUREMENT_${i}_LABEL): Avg. Power [Watts]:\" $(eval echo \$MEASUREMENT_${i}_POWER_AVG)" | tee -a $output metrics.txt
            echo "\"${CI_JOB_NAME}: Label: $(eval echo \$MEASUREMENT_${i}_LABEL): Duration [seconds]:\" $(eval echo \$MEASUREMENT_${i}_TIME)" | tee -a $output metrics.txt
            echo "----------------" >> $output
        done
    fi

    if [[ ${display_table} == 'true' ]]; then
        ## Used for the main output display for github (step summary) / gitlab (artifacts)
        echo "Eco-CI Output: " >> $output_pr
        echo "|Label|🖥 avg. CPU utilization [%]|🔋 Total Energy [Joules]|🔌 avg. Power [Watts]|Duration [Seconds]|" | tee -a $output $output_pr
        echo "|---|---|---|---|---|" | tee -a $output $output_pr
        echo "|Total Run (incl. overhead)|$cpu_avg|$total_energy|$power_avg|$total_time|" | tee -a $output $output_pr
        #display measurument lines in table summary
        for (( i=1; i<=$MEASUREMENT_COUNT; i++ ))
        do
            echo "|$(eval echo \$MEASUREMENT_${i}_LABEL)|$(eval echo \$MEASUREMENT_${i}_CPU_AVG)|$(eval echo \$MEASUREMENT_${i}_ENERGY)|$(eval echo \$MEASUREMENT_${i}_POWER_AVG)|$(eval echo \$MEASUREMENT_${i}_TIME)|" | tee -a $output $output_pr
        done
        echo '' | tee -a $output $output_pr
    fi


    if [[ ${CALCULATE_CO2} == 'true' ]]; then
        source "$(dirname "$0")/misc.sh"
        get_energy_co2 "$total_energy"
        get_embodied_co2 "$total_time"
        read_vars # reload set vars

        # CO2 API might have failed or not set, so we only calculate total if it worked
        CO2EQ_EMBODIED=${CO2EQ_EMBODIED:-}  # Default to an empty string if unset
        CO2EQ_ENERGY=${CO2EQ_ENERGY:-}      # Default to an empty string if unset
        GEO_IP=${GEO_IP:-}      # Default to an empty string if unset
        GEO_CITY=${GEO_CITY:-}      # Default to an empty string if unset
        GEO_LAT=${GEO_LAT:-}      # Default to an empty string if unset
        GEO_LON=${GEO_LON:-}      # Default to an empty string if unset

        if [ -n "$CO2EQ_EMBODIED" ] && [ -n "$CO2EQ_ENERGY" ]; then # We only check for co2 as if this is set the others should be set too
            CO2EQ=$(echo "$CO2EQ_EMBODIED $CO2EQ_ENERGY" | awk '{printf "%.9f", $1 + $2}')

            echo '🌳 CO2 Data:' | tee -a $output $output_pr
            echo "City: <b>$GEO_CITY</b>, Lat: <b>$GEO_LAT</b>, Lon: <b>$GEO_LON</b>" | tee -a $output $output_pr
            echo "IP: <b>$GEO_IP</b>" | tee -a $output $output_pr
            echo "CO₂ from energy is: $CO2EQ_ENERGY" | tee -a $output $output_pr
            echo "CO₂ from manufacturing (embodied carbon) is: $CO2EQ_EMBODIED" | tee -a $output $output_pr
            echo "<a href='https://www.electricitymaps.com/methodology#carbon-intensity-and-emission-factors' target=_blank rel=noopener>Carbon Intensity</a> for this location: <b>$CO2I gCO₂eq/kWh</b>" | tee -a $output $output_pr
            printf "<a href='https://sci-guide.greensoftware.foundation/'  target=_blank rel=noopener>SCI</a>: <b>%.6f gCO₂eq / pipeline run</b> emitted\n" $CO2EQ | tee -a $output $output_pr
        else
            echo '❌ CO2 Data:' | tee -a $output $output_pr
            echo "Error in retrieving values. Please see the detailed logs for the exact error messages!" | tee -a $output $output_pr
        fi

    fi

    if [[ ${SEND_DATA} == 'true' && ${display_badge} == 'true' ]]; then
        repo_enc=$( echo ${REPOSITORY} | jq -Rr @uri)
        branch_enc=$( echo ${BRANCH} | jq -Rr @uri)
        get_endpoint=$DASHBOARD_API_BASE"/v1/ci/measurement/get"
        metrics_url="https://metrics.green-coding.io"

        echo "Badge for your README.md:" >> $output
        echo ' ```' >> $output
        echo "[![Energy Used](${get_endpoint}?repo=${repo_enc}&branch=${branch_enc}&workflow=$WORKFLOW_ID)](${metrics_url}/ci.html?repo=${repo_enc}&branch=${branch_enc}&workflow=$WORKFLOW_ID)" >> $output
        echo ' ```' >> $output

        echo "See energy runs here:" >> $output
        echo "${metrics_url}/ci.html?repo=${repo_enc}&branch=${branch_enc}&workflow=$WORKFLOW_ID" >> $output
    fi

    if [[ ${JSON_OUTPUT} == 'true' ]]; then
        # write data to output
        total_data_file="/tmp/eco-ci/total-data.json"

        echo "show create-and-add-meta.sh output"
        source "$(dirname "$0")/create-and-add-meta.sh" create_json_file "${total_data_file}"
        source "$(dirname "$0")/add-data.sh" "${total_data_file}" "TOTAL" "${cpu_avg}" "${total_energy}" "${power_avg}" "${total_time}"
    fi
}

option="$1"
case $option in
  display_results)
    display_results $2 $3
    ;;
esac

