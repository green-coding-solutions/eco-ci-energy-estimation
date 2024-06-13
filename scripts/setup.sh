#!/usr/bin/env bash
set -euo pipefail

# Call the function to read and set the variables
source "$(dirname "$0")/vars.sh" read_vars

function initialize {

    if [[ -d /tmp/eco-ci ]]; then
      rm -rf /tmp/eco-ci
    fi
    mkdir -p "/tmp/eco-ci"

    # call init_variables
    source "$(dirname "$0")/vars.sh" add_var "MACHINE_POWER_DATA" "$1"
    source "$(dirname "$0")/vars.sh" cpu_vars "$1"
    source "$(dirname "$0")/vars.sh" add_var DASHBOARD_API_BASE "https://api.green-coding.io"
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
    bash "$(dirname "$0")/cpu-utilization.sh" > /tmp/eco-ci/cpu-util-step.txt &

}

# Main script logic
if [ $# -eq 0 ]; then
  echo "No option provided. Please specify an option: initialize, or start_measurement."
  exit 1
fi


option="$1"
case $option in
  initialize)
    initialize $2
    ;;
  start_measurement)
    start_measurement
    ;;
  lap_measurement)
    lap_measurement
    ;;
  *)
    echo "Invalid option ${option}. Please specify an option: initialize, lap_measurement or start_measurement."
    exit 1
    ;;
esac
