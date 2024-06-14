#!/usr/bin/env bash
set -euo pipefail

# Call the function to read and set the variables
source "$(dirname "$0")/vars.sh" read_vars

function display_results {
    # First get values, in case any are unbound
    # this will set them to an empty string if they are missing entirely
    MEASUREMENT_RAN=${MEASUREMENT_RAN:-}
    MEASUREMENT_COUNT=${MEASUREMENT_COUNT:-}
    WORKFLOW_ID=${WORKFLOW_ID:-}
    DASHBOARD_API_BASE=${DASHBOARD_API_BASE:-}

    output="/tmp/eco-ci/output.txt"
    output_pr="/tmp/eco-ci/output-pr.txt"

    if [[ $(wc -l < /tmp/eco-ci/energy-total.txt) -gt 0 ]]; then
        echo "Could not display table as no measurement data was present!"
        [ -n "$GITHUB_STEP_SUMMARY" ] && echo "❌ Could not display table as no measurement data was present!" >> $GITHUB_STEP_SUMMARY
        return 1
    fi

    cpu_avg=$(awk '{ total += $2; count++ } END { print total/count }' /tmp/eco-ci/cpu-util-total.txt)
    total_energy=$(awk '{sum+=$1} END {print sum}' /tmp/eco-ci/energy-total.txt)
    total_time=$(($(date +%s) - $(cat /tmp/eco-ci/timer-total.txt)))
    power_acc=$(awk '{ total += $1; } END { print total }' /tmp/eco-ci/energy-total.txt)
    total_power=$(echo "scale=2; $power_acc / $total_time"  | bc -l)

    ## Gitlab Specific Output
    if [[ $source == 'gitlab' ]]; then
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
        if [[ $source == 'github' ]]; then
            echo "Eco-CI Output: " >> $output_pr
            echo "|Label|🖥 avg. CPU utilization [%]|🔋 Total Energy [Joules]|🔌 avg. Power [Watts]|Duration [Seconds]|" | tee -a $output $output_pr
            echo "|---|---|---|---|---|" | tee -a $output $output_pr
            echo "|Total Run|$cpu_avg|$total_energy|$power_avg|$total_time|" | tee -a $output $output_pr
            #display measurument lines in table summary
            for (( i=1; i<=$max_measurement_number; i++ ))
            do
                echo "|$(eval echo \$MEASUREMENT_${i}_LABEL)|$(eval echo \$MEASUREMENT_${i}_CPU_AVG)|$(eval echo \$MEASUREMENT_${i}_TOTAL_ENERGY)|$(eval echo \$MEASUREMENT_${i}_POWER_AVG)|$(eval echo \$MEASUREMENT_${i}_TIME)|" | tee -a $output $output_pr
            done
            echo '' | tee -a $output $output_pr
        fi
    fi

    if [[ ${display_graph} == 'true' ]]; then
        if [[ $source == 'github' ]]; then
            echo '📈 Energy graph:' | tee -a $output $output_pr
            echo '```bash' | tee -a $output $output_pr
            echo ' ' | tee -a $output $output_pr
            docker run --rm -i greencoding/cloud-energy:latest-asciicharts /home/worker/go/bin/asciigraph -h 10 -c "Watts over time" < /tmp/eco-ci/energy-total.txt | tee -a $output $output_pr
            echo ' ```' | tee -a $output $output_pr
        elif [[ $source == 'gitlab' ]]; then
            echo '📈 Energy graph:' >> $output
            docker run --rm -i greencoding/cloud-energy:latest-asciicharts /home/worker/go/bin/asciigraph -h 10 -c "Watts over time" < /tmp/eco-ci/energy-total.txt >> $output
        fi
    fi
    repo_enc=$( echo ${repo} | jq -Rr @uri)
    branch_enc=$( echo ${branch} | jq -Rr @uri)

    if [[ ${show_carbon} == 'true' ]]; then
        source "$(dirname "$0")/misc.sh" get_energy_co2 "$total_energy"
        source "$(dirname "$0")/misc.sh" get_embodied_co2 "$total_time"


        if [ -n "$CO2EQ_EMBODIED" ] && [ -n "$CO2EQ_ENERGY" ]; then # We only check for co2 as if this is set the others should be set too
            CO2EQ=$(echo "$CO2EQ_EMBODIED + $CO2EQ_ENERGY" | bc -l)

            echo '🌳 CO2 Data:' | tee -a $output $output_pr
            echo "City: <b>$CITY</b>, Lat: <b>$LAT</b>, Lon: <b>$LON</b>" | tee -a $output $output_pr
            echo "CO₂ from energy is: $CO2EQ_ENERGY" | tee -a $output $output_pr
            echo "CO₂ from manufacturing (embodied carbon) is: $CO2EQ_EMBODIED" | tee -a $output $output_pr
            echo "<a href='https://www.electricitymaps.com/methodology#carbon-intensity-and-emission-factors' target=_blank rel=noopener>Carbon Intensity</a> for this location: <b>$CO2I gCO₂eq/kWh</b>" | tee -a $output $output_pr
            printf "<a href='https://sci-guide.greensoftware.foundation/'  target=_blank rel=noopener>SCI</a>: <b>%.6f gCO₂eq / pipeline run</b> emitted\n" $CO2EQ | tee -a $output $output_pr
        else
            echo '❌ CO2 Data:' | tee -a $output $output_pr
            echo "Error in retrieving values. Please see the detailed logs for the exact error messages!" | tee -a $output $output_pr
        fi

    fi


    if [[ ${send_data} == 'true' && ${display_badge} == 'true' ]]; then
        get_endpoint=$DASHBOARD_API_BASE"/v1/ci/measurement/get"
        metrics_url="https://metrics.green-coding.io"

        echo "Badge for your README.md:" >> $output
        echo ' ```' >> $output
        echo "[![Energy Used](${get_endpoint}?repo=${repo_enc}&branch=${branch_enc}&workflow=$WORKFLOW_ID)](${metrics_url}/ci.html?repo=${repo_enc}&branch=${branch_enc}&workflow=$WORKFLOW_ID)" >> $output
        echo ' ```' >> $output

        echo "See energy runs here:" >> $output
        echo "${metrics_url}/ci.html?repo=${repo_enc}&branch=${branch_enc}&workflow=$WORKFLOW_ID" >> $output
    fi

    # write data to output
    total_data_file="/tmp/eco-ci/total-data.json"
    run_id_enc=$( echo ${run_id} | jq -Rr @uri)

    echo "show create-and-add-meta.sh output"
    echo "--file $total_data_file --repository $repo_enc --branch $branch_enc --workflow $WORKFLOW_ID --run_id $run_id_enc"
    source "$(dirname "$0")/create-and-add-meta.sh" --file "${total_data_file}" --repository "${repo_enc}" --branch "${branch_enc}" --workflow "$WORKFLOW_ID" --run_id "${run_id_enc}"
    source "$(dirname "$0")/add-data.sh" --file "${total_data_file}" --label "TOTAL" --cpu "${cpu_avg}" --energy "${total_energy}" --power "${power_avg}" --time "${total_time}"

}

branch=""
display_badge=""
run_id=""
repo=""
display_table=""
display_graph=""
send_data=""
show_carbon=""
source=""

while [[ $# -gt 0 ]]; do
    opt="$1"

    case $opt in
        -b|--branch)
        branch="$2"
        shift
        ;;
        -db|--display-badge)
        display_badge="$2"
        shift
        ;;
        -r|--run-id)
        run_id="$2"
        shift
        ;;
        -R|--repo)
        repo="$2"
        shift
        ;;
        -dt|--display-table)
        display_table="$2"
        shift
        ;;
        -dg|--display-graph)
        display_graph="$2"
        shift
        ;;
        -sd|--send-data)
        send_data="$2"
        shift
        ;;
        -sc|--show-carbon)
        show_carbon="$2"
        shift
        ;;
        -s|--source)
        source="$2"
        shift
        ;;
        *) echo "Invalid option -$1" >&2
        exit 1
        ;;
    esac
    shift
done

display_results
