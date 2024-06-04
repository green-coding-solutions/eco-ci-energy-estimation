#!/usr/bin/env bash
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
    source "$(dirname "$0")/vars.sh" add_var API_BASE "https://api.green-coding.io"
}


function start_measurement {
    # start global timer
    touch /tmp/eco-ci/cpu-util.txt
    date +%s > /tmp/eco-ci/timer-total.txt
    lap_measurement
}

function lap_measurement {
    # start step timer
    date +%s > /tmp/eco-ci/timer.txt

    container_exists=$(docker ps -a -q -f name=^/cloud-energy-cpu-utilization$)

    if [ -n "$container_exists" ]; then
        docker logs cloud-energy-cpu-utilization | tee -a /tmp/eco-ci/cpu-util-total.txt > /tmp/eco-ci/cpu-util.txt
        docker rm -f cloud-energy-cpu-utilization
    fi
    docker run --rm -d --name cloud-energy-cpu-utilization greencoding/cloud-energy:latest-asciicharts /home/worker/cpu-utilization
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
