#!/bin/bash

# Call the function to read and set the variables
source "$(dirname "$0")/vars.sh" read_vars

function display_results {
    output="/tmp/eco-ci/output.txt"
    output_pr="/tmp/eco-ci/output-pr.txt"

    if [[ $MEASUREMENT_RAN != true ]]; then
        echo "Running a measurement to have at least one result to display."
        source /tmp/eco-ci/venv/bin/activate

        if [[ "$MODEL_NAME" == "unknown" ]]; then
            cat /tmp/eco-ci/cpu-util.txt | python3. /tmp/eco-ci/spec-power-model/xgb.py --silent | tee -a /tmp/eco-ci/energy-total.txt > /tmp/eco-ci/energy.txt
        else
            cat /tmp/eco-ci/cpu-util.txt | python3 /tmp/eco-ci/spec-power-model/xgb.py \
            --tdp $TDP --cpu-threads $CPU_THREADS \
            --cpu-cores $CPU_CORES --cpu-make $CPU_MAKE \
            --release-year $RELEASE_YEAR --ram $RAM \
            --cpu-freq $CPU_FREQ --cpu-chips $CPU_CHIPS \
            --vhost-ratio $VHOST_RATIO --silent | tee -a /tmp/eco-ci/energy-total.txt > /tmp/eco-ci/energy.txt
        fi

        # reactivate the old venv, if it was present
        if [[ $PREVIOUS_VENV != '' ]]; then
          source $PREVIOUS_VENV/bin/activate
        fi
    fi

    cpu_avg=$(awk '{ total += $1; count++ } END { print total/count }' /tmp/eco-ci/cpu-util-total.txt)
    total_energy=$(awk '{sum+=$1} END {print sum}' /tmp/eco-ci/energy-total.txt)
    power_avg=$(awk '{ total += $1; count++ } END { print total/count }' /tmp/eco-ci/energy-total.txt)
    time=$(($(date +%s) - $(cat /tmp/eco-ci/timer-total.txt)))

    # Get series of measurement values
    for varname in ${!measurement_@}; do
        # Extract the measurement number from the variable name
        measurement_number="${varname#*_}"
        # Extract the value of the current measurement variable
        measurement_value="${!varname}"

        # Use eval to assign individual variables based on the measurement value
        eval "label_${measurement_number}=$(echo $measurement_value | awk -F'[,:]' '{print $2}')"
        eval "cpu_avg_${measurement_number}=$(echo $measurement_value | awk -F'[,:]' '{print $4}')"
        eval "total_energy_${measurement_number}=$(echo $measurement_value | awk -F'[,:]' '{print $6}')"
        eval "power_avg_${measurement_number}=$(echo $measurement_value | awk -F'[,:]' '{print $8}')"
        eval "time_${measurement_number}=$(echo $measurement_value | awk -F'[,:]' '{print $10}')"

        max_measurement_number=$measurement_number
    done

    ## Gitlab Specific Output
    if [[ $source == 'gitlab' ]]; then
        echo "\"$CI_JOB_NAME: Energy [Joules]:\" $total_energy" | tee -a $output metrics.txt
        echo "\"$CI_JOB_NAME: Avg. CPU Utilization:\" $cpu_avg" | tee -a $output metrics.txt
        echo "\"$CI_JOB_NAME: Avg. Power [Watts]:\" $power_avg" | tee -a $output metrics.txt
        echo "\"$CI_JOB_NAME: Duration [seconds]:\" $time" | tee -a $output metrics.txt
        echo "----------------" >> $output

        for (( i=1; i<=$max_measurement_number; i++ )); do
            echo "\"${CI_JOB_NAME}: Label: $(eval echo \$label_$i): Energy Used [Joules]:\" $(eval echo \$total_energy_$i)" | tee -a $output metrics.txt
            echo "\"${CI_JOB_NAME}: Label: $(eval echo \$label_$i): Avg. CPU Utilization:\" $(eval echo \$cpu_avg_$i)" | tee -a $output metrics.txt
            echo "\"${CI_JOB_NAME}: Label: $(eval echo \$label_$i): Avg. Power [Watts]:\" $(eval echo \$power_avg_$i)" | tee -a $output metrics.txt
            echo "\"${CI_JOB_NAME}: Label: $(eval echo \$label_$i): Duration [seconds]:\" $(eval echo \$time_$i)" | tee -a $output metrics.txt
            echo "----------------" >> $output
        done
    fi
    
    if [[ ${display_table} == 'true' ]]; then
        ## Used for the main output display for github (step summary) / gitlab (artifacts)
        if [[ $source == 'github' ]]; then
            echo "Eco-CI Output: " >> $output_pr
            echo "|Label|🖥 avg. CPU utilization [%]|🔋 Total Energy [Joules]|🔌 avg. Power [Watts]|Duration [Seconds]|" | tee -a $output $output_pr
            echo "|---|---|---|---|---|" | tee -a $output $output_pr
            echo "|Total Run|$cpu_avg|$total_energy|$power_avg|$time|" | tee -a $output $output_pr
            #display measurument lines in table summary
            for (( i=1; i<=$max_measurement_number; i++ ))
            do
                echo "|$(eval echo \$label_$i)|$(eval echo \$cpu_avg_$i)|$(eval echo \$total_energy_$i)|$(eval echo \$power_avg_$i)|$(eval echo \$time_$i)|" | tee -a $output $output_pr
            done
            echo '' | tee -a $output $output_pr
        fi
    fi

    if [[ ${display_graph} == 'true' ]]; then
        if [[ $source == 'github' ]]; then
            echo '📈 Energy graph:' | tee -a $output $output_pr
            echo '```bash' | tee -a $output $output_pr
            echo ' ' | tee -a $output $output_pr
            cat /tmp/eco-ci/energy-total.txt | /home/runner/go/bin/asciigraph -h 10 -c "Watts over time" | tee -a $output $output_pr
            echo ' ```' | tee -a $output $output_pr
        elif [[ $source == 'gitlab' ]]; then
            echo '📈 Energy graph:' >> $output
            cat /tmp/eco-ci/energy-total.txt | /home/runner/go/bin/asciigraph -h 10 -c "Watts over time" >> $output
        fi
    fi
    repo_enc=$( echo ${repo} | jq -Rr @uri)
    branch_enc=$( echo ${branch} | jq -Rr @uri)

    if [[ ${send_data} == 'true' && ${display_badge} == 'true' ]]; then
        get_endpoint=$API_BASE"/v1/ci/measurement/get"
        metrics_url="https://metrics.green-coding.berlin"

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
    source "$(dirname "$0")/create-and-add-meta.sh" --file ${total_data_file} --repository ${repo_enc} --branch ${branch_enc} --workflow $WORKFLOW_ID --run_id ${run_id_enc}
    source "$(dirname "$0")/add-data.sh" --file ${total_data_file} --label "TOTAL" --cpu ${cpu_avg} --energy ${total_energy} --power ${power_avg}

}

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
        -s|--source)
        source="$2"
        shift
        ;;
        \?) echo "Invalid option -$1" >&2
        ;;
    esac
    shift
done

display_results
