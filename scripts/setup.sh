#!/usr/bin/env sh
set -euo pipefail

# Call the function to read and set the variables
source "$(dirname "$0")/vars.sh" read_vars

function initialize {

    if [[ $reset == true ]]; then
        if [[ -d /tmp/eco-ci ]]; then
          rm -rf /tmp/eco-ci
        fi
        mkdir /tmp/eco-ci
    fi
    # call init_variables
    source "$(dirname "$0")/vars.sh" cpu_vars
    source "$(dirname "$0")/vars.sh" add_var DASHBOARD_API_BASE "https://api.green-coding.io"

    if [[ -n "$BASH_VERSION" ]] && (( ${BASH_VERSION:0:1} >= 4 )); then
        source "$(dirname "$0")/machine-power-data/${MACHINE_POWER_DATA}"
        source "$(dirname "$0")/vars.sh" add_var MACHINE_POWER_HASHMAP $cloud_energy_hashmap
    fi
}


function start_measurement {
    touch /tmp/eco-ci/cpu-util-step.txt
    touch /tmp/eco-ci/cpu-util-total.txt
    touch /tmp/eco-ci/cpu-energy-step.txt
    touch /tmp/eco-ci/cpu-energy-total.txt
    touch /tmp/eco-ci/timer-step.txt

    # start global timer
    date +%s > /tmp/eco-ci/timer-total.txt
    lap_measurement
}

function lap_measurement {
    # start step timer
    date +%s > /tmp/eco-ci/timer-step.txt

    # start writing cpu utilization with actual sleep durations
    sh "$(dirname "$0")/cpu-utilization.sh" > /tmp/eco-ci/cpu-util-step.txt &

}

# Main script logic
if [ $# -eq 0 ]; then
  echo "No option provided. Please specify an option: initialize, or start_measurement."
  exit 1
fi


option="$1"

case $option in
  initialize)
    func=initialize
    ;;
  start_measurement)
    func=start_measurement
    ;;
  lap_measurement)
    func=lap_measurement
    ;;
  *)
    echo "Invalid option. Please specify an option: initialize, lap_measurement or start_measurement."
    exit 1
    ;;
esac

reset=true

while [[ $# -gt 1 ]]; do
    opt="$2"

    case $opt in
        -r|--reset) 
        reset=$3
        shift
        ;;
        \?) echo "Invalid option -$2" >&2
        ;;
    esac
    shift
done

if [[ $func == initialize ]]; then
    initialize
elif [[ $func == start_measurement ]]; then
    start_measurement
elif [[ $func == lap_measurement ]]; then
    lap_measurement
fi
