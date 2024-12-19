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
    GITHUB_STEP_SUMMARY=${GITHUB_STEP_SUMMARY:-}

    output='/tmp/eco-ci/output.txt'
    output_pr='/tmp/eco-ci/output-pr.txt'

    if [[ $(wc -l < /tmp/eco-ci/energy-total.txt) -eq 0 ]]; then
        echo 'Could not display table as no measurement data was present!'
        [ -n "$GITHUB_STEP_SUMMARY" ] && echo '❌ Could not display table as no measurement data was present!' >> $GITHUB_STEP_SUMMARY
        return 1
    fi

    cpu_avg=$(awk '{ total += $2; count++ } END { print total/count }' /tmp/eco-ci/cpu-util-total.txt)
    total_energy=$(awk '{sum+=$1} END {print sum}' /tmp/eco-ci/energy-total.txt)
    total_time_us=$(($(date "+%s%6N") - $(cat /tmp/eco-ci/timer-total.txt)))
    total_time_s=$(echo "${total_time_us} 1000000" | awk '{printf "%.2f", $1 / $2}')
    power_avg=$(echo "${total_energy} ${total_time_s}" | awk '{printf "%.2f", $1 / $2}')



    if [[ "${display_table}" == 'true' ]]; then
        ## Used for the main output display for github (step summary) / gitlab (artifacts)

        ## Gitlab Specific Output
        if [[ "$ECO_CI_SOURCE" == 'gitlab' ]]; then
            # CI_JOB_NAME is a set variable by GitLab
            echo "\"${CI_JOB_NAME}: Energy [Joules]:\" $total_energy" | tee -a $output metrics.txt
            echo "\"${CI_JOB_NAME}: Avg. CPU Utilization:\" $cpu_avg" | tee -a $output metrics.txt
            echo "\"${CI_JOB_NAME}: Avg. Power [Watts]:\" $power_avg" | tee -a $output metrics.txt
            echo "\"${CI_JOB_NAME}: Duration [seconds]:\" $total_time_s" | tee -a $output metrics.txt
            echo "----------------" >> $output

            for (( i=1; i<=$ECO_CI_MEASUREMENT_COUNT; i++ )); do
                echo "\"${CI_JOB_NAME}: Label: $(eval echo \$ECO_CI_MEASUREMENT_${i}_LABEL): Energy Used [Joules]:\" $(eval echo \$ECO_CI_MEASUREMENT_${i}_ENERGY)" | tee -a $output metrics.txt
                echo "\"${CI_JOB_NAME}: Label: $(eval echo \$ECO_CI_MEASUREMENT_${i}_LABEL): Avg. CPU Utilization:\" $(eval echo \$ECO_CI_MEASUREMENT_${i}_CPU_AVG)" | tee -a $output metrics.txt
                echo "\"${CI_JOB_NAME}: Label: $(eval echo \$ECO_CI_MEASUREMENT_${i}_LABEL): Avg. Power [Watts]:\" $(eval echo \$ECO_CI_MEASUREMENT_${i}_POWER_AVG)" | tee -a $output metrics.txt
                echo "\"${CI_JOB_NAME}: Label: $(eval echo \$ECO_CI_MEASUREMENT_${i}_LABEL): Duration [seconds]:\" $(eval echo \$ECO_CI_MEASUREMENT_${i}_TIME)" | tee -a $output metrics.txt
                echo "----------------" >> $output
            done
        else
            echo "Eco-CI Output: " >> $output_pr
            echo "|Label|🖥 avg. CPU utilization [%]|🔋 Total Energy [Joules]|🔌 avg. Power [Watts]|Duration [Seconds]|" | tee -a $output $output_pr
            echo "|---|---|---|---|---|" | tee -a $output $output_pr
            echo "|Total Run (incl. overhead)|$cpu_avg|$total_energy|$power_avg|$total_time_s|" | tee -a $output $output_pr
            #display measurument lines in table summary
            for (( i=1; i<=$ECO_CI_MEASUREMENT_COUNT; i++ ))
            do
                echo "|$(eval echo \$ECO_CI_MEASUREMENT_${i}_LABEL)|$(eval echo \$ECO_CI_MEASUREMENT_${i}_CPU_AVG)|$(eval echo \$ECO_CI_MEASUREMENT_${i}_ENERGY)|$(eval echo \$ECO_CI_MEASUREMENT_${i}_POWER_AVG)|$(eval echo \$ECO_CI_MEASUREMENT_${i}_TIME)|" | tee -a $output $output_pr
            done
            echo '' | tee -a $output $output_pr
        fi
    fi

    repo_enc=$( echo ${ECO_CI_REPOSITORY} | jq -Rr @uri)
    branch_enc=$( echo ${ECO_CI_BRANCH} | jq -Rr @uri)

    if [[ ${ECO_CI_CALCULATE_CO2} == 'true' ]]; then
        source "$(dirname "$0")/misc.sh"
        get_energy_co2 "$total_energy"
        get_embodied_co2 "$total_time_s"
        read_vars # reload set vars

        # CO2 API might have failed or not set, so we only calculate total if it worked
        ECO_CI_CO2EQ_EMBODIED=${ECO_CI_CO2EQ_EMBODIED:-}  # Default to an empty string if unset
        ECO_CI_CO2EQ_ENERGY=${ECO_CI_CO2EQ_ENERGY:-}      # Default to an empty string if unset
        ECO_CI_GEO_IP=${ECO_CI_GEO_IP:-}      # Default to an empty string if unset
        ECO_CI_GEO_CITY=${ECO_CI_GEO_CITY:-}      # Default to an empty string if unset
        ECO_CI_GEO_LAT=${ECO_CI_GEO_LAT:-}      # Default to an empty string if unset
        ECO_CI_GEO_LON=${ECO_CI_GEO_LON:-}      # Default to an empty string if unset

        if [ -n "$ECO_CI_CO2EQ_EMBODIED" ] && [ -n "$ECO_CI_CO2EQ_ENERGY" ]; then # We only check for co2 as if this is set the others should be set too
            ECO_CI_CO2EQ=$(echo "$ECO_CI_CO2EQ_EMBODIED $ECO_CI_CO2EQ_ENERGY" | awk '{printf "%.9f", $1 + $2}')

            echo '🌳 CO2 Data:' | tee -a $output $output_pr
            echo "City: <b>${ECO_CI_GEO_CITY}</b>, Lat: <b>${ECO_CI_GEO_LAT}</b>, Lon: <b>${ECO_CI_GEO_LON}</b>" | tee -a $output $output_pr
            echo "IP: <b>${ECO_CI_GEO_IP}</b>" | tee -a $output $output_pr
            echo "CO₂ from energy is: ${ECO_CI_CO2EQ_ENERGY} g" | tee -a $output $output_pr
            echo "CO₂ from manufacturing (embodied carbon) is: ${ECO_CI_CO2EQ_EMBODIED} g" | tee -a $output $output_pr
            echo "<a href='https://www.electricitymaps.com/methodology#carbon-intensity-and-emission-factors' target=_blank rel=noopener>Carbon Intensity</a> for this location: <b>${ECO_CI_CO2I} gCO₂eq/kWh</b>" | tee -a $output $output_pr
            printf "<a href='https://sci-guide.greensoftware.foundation/'  target=_blank rel=noopener>SCI</a>: <b>%.6f gCO₂eq / pipeline run</b> emitted\n" ${ECO_CI_CO2EQ} | tee -a $output $output_pr

            if [[ "${display_badge}" == 'true' ]]; then
                echo "Total cost of whole PR so far:<br>"
                echo "<a href='${ECO_CI_DASHBOARD_URL}/ci.html?repo=${repo_enc}&branch=${branch_enc}&workflow=${ECO_CI_WORKFLOW_ID}'><img src='${ECO_CI_API_ENDPOINT_BADGE_GET}?repo=${repo_enc}&branch=${branch_enc}&workflow=${ECO_CI_WORKFLOW_ID}&mode=totals&metric=energy'></a>" | tee -a $output $output_pr
                echo "<a href='${ECO_CI_DASHBOARD_URL}/ci.html?repo=${repo_enc}&branch=${branch_enc}&workflow=${ECO_CI_WORKFLOW_ID}'><img src='${ECO_CI_API_ENDPOINT_BADGE_GET}?repo=${repo_enc}&branch=${branch_enc}&workflow=${ECO_CI_WORKFLOW_ID}&mode=totals&metric=carbon'></a>" | tee -a $output $output_pr
            fi
        else
            echo '❌ CO2 Data:' | tee -a $output $output_pr
            echo 'Error in retrieving values. Please see the detailed logs for the exact error messages!' | tee -a $output $output_pr
        fi

    fi

    if [[ "${ECO_CI_SEND_DATA}" == 'true' && "${display_badge}" == 'true' ]]; then
        echo "Badge for your README.md:" >> $output
        echo ' ```' >> $output
        echo "[![Energy Used](${ECO_CI_API_ENDPOINT_BADGE_GET}?repo=${repo_enc}&branch=${branch_enc}&workflow=${ECO_CI_WORKFLOW_ID})](${ECO_CI_DASHBOARD_URL}/ci.html?repo=${repo_enc}&branch=${branch_enc}&workflow=${ECO_CI_WORKFLOW_ID})" >> $output
        echo "[![Carbon emitted](${ECO_CI_API_ENDPOINT_BADGE_GET}?repo=${repo_enc}&branch=${branch_enc}&workflow=${ECO_CI_WORKFLOW_ID})](${ECO_CI_DASHBOARD_URL}/ci.html?repo=${repo_enc}&branch=${branch_enc}&workflow=${ECO_CI_WORKFLOW_ID}&metric=carbon)" >> $output
        echo ' ```' >> $output

        echo 'See energy runs here:' >> $output
        echo "${ECO_CI_DASHBOARD_URL}/ci.html?repo=${repo_enc}&branch=${branch_enc}&workflow=${ECO_CI_WORKFLOW_ID}" >> $output
    fi

    if [[ ${ECO_CI_JSON_OUTPUT} == 'true' ]]; then
        total_data_file="/tmp/eco-ci/total-data.json"
        echo 'show create-and-add-meta.sh output'
        source "$(dirname "$0")/create-and-add-meta.sh" create_json_file "${total_data_file}"
        source "$(dirname "$0")/add-data.sh" create_json_file "${total_data_file}" 'TOTAL' "${cpu_avg}" "${total_energy}" "${power_avg}" "${total_time_s}"
    fi
}

option="$1"
case $option in
  display_results)
    display_results "$2" "$3"
    ;;
esac

