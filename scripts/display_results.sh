#!/usr/bin/env bash
set -euo pipefail

# Call the function to read and set the variables
source "$(dirname "$0")/vars.sh"
read_vars

function display_results {
    local display_table="$1"
    local display_badge="$2"

    # First get values, in case any are unbound
    # this will set them to an empty string if they are missing entirely
    GITHUB_STEP_SUMMARY=${GITHUB_STEP_SUMMARY:-}

    local output='/tmp/eco-ci/output.txt'
    local output_pr='/tmp/eco-ci/output-pr.txt'

    if [[ $(wc -l < /tmp/eco-ci/energy-total.txt) -eq 0 ]]; then
        echo 'Could not display table as no measurement data was present!' >&2
        [ -n "$GITHUB_STEP_SUMMARY" ] && echo '❌ Could not display table as no measurement data was present!' >> $GITHUB_STEP_SUMMARY
        return 1
    fi

    local total_energy_with_overhead=$(awk '{sum+=$1} END {print sum}' /tmp/eco-ci/energy-total.txt)
    local total_time_us_with_overhead=$(($(date "+%s%6N") - $(cat /tmp/eco-ci/timer-total.txt)))
    local total_time_s_with_overhead=$(echo "${total_time_us_with_overhead} 1000000" | awk '{printf "%.2f", $1 / $2}')

    local total_energy=0
    local total_time_s=0
    local total_cpu_avg_weighted=0

    if [[ "${display_table}" == 'true' ]]; then
        ## Used for the main output display for github (step summary) / gitlab (artifacts)

        if [[ "$ECO_CI_SOURCE" != 'gitlab' ]]; then
                echo "Eco CI Output: " >> $output_pr
                echo "|Label|🖥 avg. CPU utilization [%]|🔋 Total Energy [Joules]|🔌 avg. Power [Watts]|Duration [Seconds]|" | tee -a $output $output_pr
                echo "|---|---|---|---|---|" | tee -a $output $output_pr
        fi

        for (( i=1; i<=$ECO_CI_MEASUREMENT_COUNT; i++ )); do
            if [[ "$ECO_CI_SOURCE" == 'gitlab' ]]; then
                    # CI_JOB_NAME is a set variable by GitLab
                    echo "\"${CI_JOB_NAME}: Label: $(eval echo \$ECO_CI_MEASUREMENT_${i}_LABEL): Energy Used [Joules]:\" $(eval echo \$ECO_CI_MEASUREMENT_${i}_ENERGY)" | tee -a $output metrics.txt
                    echo "\"${CI_JOB_NAME}: Label: $(eval echo \$ECO_CI_MEASUREMENT_${i}_LABEL): Avg. CPU Utilization:\" $(eval echo \$ECO_CI_MEASUREMENT_${i}_CPU_AVG)" | tee -a $output metrics.txt
                    echo "\"${CI_JOB_NAME}: Label: $(eval echo \$ECO_CI_MEASUREMENT_${i}_LABEL): Avg. Power [Watts]:\" $(eval echo \$ECO_CI_MEASUREMENT_${i}_POWER_AVG)" | tee -a $output metrics.txt
                    echo "\"${CI_JOB_NAME}: Label: $(eval echo \$ECO_CI_MEASUREMENT_${i}_LABEL): Duration [seconds]:\" $(eval echo \$ECO_CI_MEASUREMENT_${i}_TIME)" | tee -a $output metrics.txt
                    echo "----------------" >> $output
            else
                echo "|$(eval echo \$ECO_CI_MEASUREMENT_${i}_LABEL)|$(eval echo \$ECO_CI_MEASUREMENT_${i}_CPU_AVG)|$(eval echo \$ECO_CI_MEASUREMENT_${i}_ENERGY)|$(eval echo \$ECO_CI_MEASUREMENT_${i}_POWER_AVG)|$(eval echo \$ECO_CI_MEASUREMENT_${i}_TIME)|" | tee -a $output $output_pr
            fi

            total_energy=$(eval echo \$ECO_CI_MEASUREMENT_${i}_ENERGY $total_energy | awk '{printf "%.2f", $1 + $2}')
            total_time_s=$(eval echo \$ECO_CI_MEASUREMENT_${i}_TIME $total_time_s | awk '{printf "%.2f", $1 + $2}')
            total_cpu_avg_weighted=$(eval echo \$ECO_CI_MEASUREMENT_${i}_CPU_AVG $total_time_s $total_cpu_avg_weighted | awk '{printf "%.2f", ($1 * $2) + $3}')

        done

        local total_power_avg=$(echo "${total_energy} ${total_time_s}" | awk '{printf "%.2f", $1 / $2}')
        local cpu_avg_weighted=$(echo "${total_cpu_avg_weighted} ${total_time_s}" | awk '{printf "%.2f", $1 / $2}')

        local eco_ci_total_energy_overhead=$(echo "${total_energy_with_overhead} ${total_energy}" | awk '{printf "%.2f", $1 - $2}')
        local eco_ci_total_time_s_overhead=$(echo "${total_time_s_with_overhead} ${total_time_s}" | awk '{printf "%.2f", $1 - $2}')
        local eco_ci_total_power_overhead=$(echo "${eco_ci_total_energy_overhead} ${eco_ci_total_time_s_overhead}" | awk '{printf "%.2f", $1 / $2}')

        if [[ "$ECO_CI_SOURCE" == 'gitlab' ]]; then
            # CI_JOB_NAME is a set variable by GitLab
            echo "\"${CI_JOB_NAME}: Energy [Joules]:\" ${total_energy}" | tee -a $output metrics.txt
            echo "\"${CI_JOB_NAME}: Avg. CPU Utilization:\" $cpu_avg_weighted" | tee -a $output metrics.txt
            echo "\"${CI_JOB_NAME}: Avg. Power [Watts]:\" ${total_power_avg}" | tee -a $output metrics.txt
            echo "\"${CI_JOB_NAME}: Duration [seconds]:\" ${total_time_s}" | tee -a $output metrics.txt
            echo "----------------" >> $output
            echo "\"${CI_JOB_NAME}: Overhead from Eco CI - Energy [Joules]:\" ${eco_ci_total_energy_overhead}" | tee -a $output metrics.txt
            echo "\"${CI_JOB_NAME}: Overhead from Eco CI - Avg. Power [Watts]:\" ${eco_ci_total_power_overhead}" | tee -a $output metrics.txt
            echo "\"${CI_JOB_NAME}: Overhead from Eco CI - Duration [seconds]:\" ${eco_ci_total_time_s_overhead}" | tee -a $output metrics.txt

        else
            echo "|---|---|---|---|---|" | tee -a $output $output_pr
            echo "|Total Run|${cpu_avg_weighted}|${total_energy}|${total_power_avg}|${total_time_s}|" | tee -a $output $output_pr
            echo "|---|---|---|---|---|" | tee -a $output $output_pr
            echo "|Additional overhead from Eco CI|N/A|${eco_ci_total_energy_overhead}|${eco_ci_total_power_overhead}|${eco_ci_total_time_s_overhead}|" | tee -a $output $output_pr
            echo '' | tee -a $output $output_pr
        fi
    fi

    local repo_enc=$( echo "${ECO_CI_REPOSITORY}" | jq -Rr @uri)
    local branch_enc=$( echo "${ECO_CI_BRANCH}" | jq -Rr @uri)

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
            printf "<a href='https://sci-guide.greensoftware.foundation/'  target=_blank rel=noopener>SCI</a>: <b>%.6f gCO₂eq / pipeline run</b> emitted\n" "${ECO_CI_CO2EQ}" | tee -a $output $output_pr

            if [[ "${display_badge}" == 'true' ]]; then
                local random_number=$((RANDOM % 1000000000 + 1))
                echo "<hr>" | tee -a $output $output_pr
                echo "Total cost of whole PR so far: <br><br>" | tee -a $output $output_pr
                echo "<a href='${ECO_CI_DASHBOARD_URL}/ci.html?repo=${repo_enc}&branch=${branch_enc}&workflow=${ECO_CI_WORKFLOW_ID}'><img src='${ECO_CI_API_ENDPOINT_BADGE_GET}?repo=${repo_enc}&branch=${branch_enc}&workflow=${ECO_CI_WORKFLOW_ID}&mode=totals&metric=energy#${random_number}'></a>" | tee -a $output $output_pr
                echo "<a href='${ECO_CI_DASHBOARD_URL}/ci.html?repo=${repo_enc}&branch=${branch_enc}&workflow=${ECO_CI_WORKFLOW_ID}'><img src='${ECO_CI_API_ENDPOINT_BADGE_GET}?repo=${repo_enc}&branch=${branch_enc}&workflow=${ECO_CI_WORKFLOW_ID}&mode=totals&metric=carbon#${random_number}'></a>" | tee -a $output $output_pr
            fi
        else
            echo '❌ CO2 Data:' | tee -a $output $output_pr
            echo 'Error in retrieving values. Please see the detailed logs for the exact error messages!' | tee -a $output $output_pr
        fi

    fi

    if [[ "${ECO_CI_SEND_DATA}" == 'true' && "${display_badge}" == 'true' ]]; then
        echo "\nBadges for your README.md - See: [GMT CI Dashboard](${ECO_CI_DASHBOARD_URL}/ci.html?repo=${repo_enc}&branch=${branch_enc}&workflow=${ECO_CI_WORKFLOW_ID})" >> $output
    fi
}

option="$1"
case $option in
  display_results)
    display_results "$2" "$3"
    ;;
esac

