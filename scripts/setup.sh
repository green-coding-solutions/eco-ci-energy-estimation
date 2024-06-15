#!/usr/bin/env bash
set -euo pipefail

# Call the function to read and set the variables
source "$(dirname "$0")/vars.sh"
read_vars

# takes argument machine_power_data = $1
function start_measurement {
    if [[ -d /tmp/eco-ci ]]; then
      rm -rf /tmp/eco-ci
    fi
    mkdir -p "/tmp/eco-ci"

    # start global timer
    date +%s > /tmp/eco-ci/timer-total.txt
    cat /tmp/eco-ci/timer-total.txt
    lap_measurement

    # call init_variables
    add_var "MACHINE_POWER_DATA" "$1"
    cpu_vars "$1"
    add_var DASHBOARD_API_BASE "https://api.green-coding.io"

    add_var RUN_ID "$2"
    add_var BRANCH "$3"
    add_var REPO "$4"
    add_var WORKFLOW_ID "$5"
    add_var WORKFLOW_NAME "$6"
    add_var COMMIT_HASH "$7"
    add_var SOURCE "$8"
    add_var SEND_DATA "$9"
    if [[ "${10}" == '-' ]]; then
        add_var CB_COMPANY_UUID ""
    else
        add_var CB_COMPANY_UUID "${10}"
    fi
    if [[ "${11}" == '-' ]]; then
        add_var CB_PROJECT_UUID ""
    else
        add_var CB_PROJECT_UUID "${11}"
    fi
    if [[ "${12}" == '-' ]]; then
        add_var CB_MACHINE_UUID ""
    else
        add_var CB_MACHINE_UUID "${12}"
    fi
    add_var CALCULATE_CO2 "${13}"
    add_var JSON_OUTPUT "${14}"

    touch /tmp/eco-ci/cpu-util-step.txt
    touch /tmp/eco-ci/cpu-util-total.txt
    touch /tmp/eco-ci/energy-step.txt
    touch /tmp/eco-ci/energy-total.txt
    touch /tmp/eco-ci/timer-step.txt

    if [[ "${13}" == 'true' ]]; then
        source "$(dirname "$0")/misc.sh"
        get_geoip # will set $GEO_CITY, $GEO_LAT, $GEO_LONG and $GEO_IP
        read_vars # reload set vars
        get_carbon_intensity # will set $CO2_INTENSITY
    fi

    # Capture current cpu util file and trim trailing empty lines from the file to not run into read/write race condition later
    sed '/^[[:space:]]*$/d' /tmp/eco-ci/cpu-util-step.txt > /tmp/eco-ci/cpu-util-temp.txt

    # this measurement we purely do for the overhead calculation
    if [[ $(wc -l < /tmp/eco-ci/cpu-util-temp.txt) -gt 0 ]]; then
        source "$(dirname "$0")/make_measurement.sh"
        make_inference # will populate /tmp/eco-ci/energy-step.txt
    fi

    # save the values for the overhead
    sed '/^[[:space:]]*$/d' /tmp/eco-ci/cpu-util-step.txt >> /tmp/eco-ci/cpu-util-total.txt
    sed '/^[[:space:]]*$/d' /tmp/eco-ci/energy-step.txt >> /tmp/eco-ci/energy-total.txt

}

function lap_measurement {
    # start step timer
    date +%s > /tmp/eco-ci/timer-step.txt

    # start writing cpu utilization with actual sleep durations
    end_measurement
    bash "$(dirname "$0")/cpu-utilization.sh" > /tmp/eco-ci/cpu-util-step.txt 2> /dev/null < /dev/null &
}

function end_measurement {
    pkill -SIGTERM -f "$(dirname "$0")/cpu-utilization.sh"  || true;
}

option="$1"
case $option in
  start_measurement)
    start_measurement $2 $3 $4 $5 $6 $7 $8 $9 ${10} ${11} ${12} ${13} ${14} ${15}
    ;;
  lap_measurement)
    lap_measurement
    ;;
  end_measurement)
    end_measurement
    ;;
esac

