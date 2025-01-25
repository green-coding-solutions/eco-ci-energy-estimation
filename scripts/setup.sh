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

    # check if date returns a timestamp accurate to microseconds (16 digits)
    # if not probably coreutils are missing (that's the case with alpine)
    microseconds=$(date "+%s%6N")
    if (( ${#microseconds} < 16 )); then
      echo "ERROR: Date has returned a timestamp that is not accurate to microseconds! You may need to install coreutils."
      exit 1
    fi

    # start global timer
    date "+%s%6N" > /tmp/eco-ci/timer-total.txt
    cat /tmp/eco-ci/timer-total.txt
    lap_measurement

    # call init_variables
    add_var 'ECO_CI_MACHINE_POWER_DATA' "$1"
    cpu_vars "$1"

    add_var 'ECO_CI_RUN_ID' "$2"
    add_var 'ECO_CI_BRANCH' "$3"
    add_var 'ECO_CI_REPOSITORY' "$4"
    add_var 'ECO_CI_WORKFLOW_ID' "$5"
    add_var 'ECO_CI_WORKFLOW_NAME' "$6"
    add_var 'ECO_CI_COMMIT_HASH' "$7"
    add_var 'ECO_CI_SOURCE' "$8"
    add_var 'ECO_CI_SEND_DATA' "$9"
    add_var 'ECO_CI_FILTER_TYPE' "${10}"
    add_var 'ECO_CI_FILTER_PROJECT' "${11}"
    add_var 'ECO_CI_FILTER_MACHINE' "${12}"
    add_var 'ECO_CI_FILTER_TAGS' "${13}"
    add_var 'ECO_CI_CALCULATE_CO2' "${14}"
    add_var 'ECO_CI_GMT_API_TOKEN' "${15}"
    add_var 'ECO_CI_ELECTRICITYMAPS_API_TOKEN' "${16}"
    add_var 'ECO_CI_JSON_OUTPUT' "${17}"
    add_var 'ECO_CI_API_ENDPOINT_ADD' "${18}"
    add_var 'ECO_CI_API_ENDPOINT_BADGE_GET' "${19}"
    add_var 'ECO_CI_DASHBOARD_URL' "${20}"

    touch /tmp/eco-ci/cpu-util-step.txt
    touch /tmp/eco-ci/cpu-util-total.txt
    touch /tmp/eco-ci/energy-step.txt
    touch /tmp/eco-ci/energy-total.txt
    touch /tmp/eco-ci/timer-step.txt

    if [[ "${14}" == 'true' ]]; then
        source "$(dirname "$0")/misc.sh"
        get_geoip # will set $ECO_CI_GEO_CITY, $ECO_CI_GEO_LAT, $ECO_CI_GEO_LONG and $ECO_CI_GEO_IP
        read_vars # reload set vars
        get_carbon_intensity # will set $ECO_CI_CO2I
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
    date "+%s%6N" > /tmp/eco-ci/timer-step.txt

    # start writing cpu utilization with actual sleep durations
    end_measurement
    if [[ $(uname) == "Darwin" ]]; then
        bash "$(dirname "$0")/cpu-utilization-macos.sh" > /tmp/eco-ci/cpu-util-step.txt 2> /dev/null < /dev/null &
    else
        bash "$(dirname "$0")/cpu-utilization-linux.sh" > /tmp/eco-ci/cpu-util-step.txt 2> /dev/null < /dev/null &
    fi
}

function kill_tree() {
    for parent_pid in "$@"; do
        kill -SIGTERM $parent_pid 2>/dev/null || true;
        local child_pids=$(pgrep -P $parent_pid)
        for child_pid in $child_pids; do
            kill_tree $child_pid
        done
    done
}


function end_measurement {
    if [[ $(uname) == "Darwin" ]]; then
        kill_tree $(pgrep -f "$(dirname "$0")/cpu-utilization-macos.sh" || true)
    else
        kill_tree $(pgrep -f "$(dirname "$0")/cpu-utilization-linux.sh" || true)
    fi
}

option="$1"

if [[ "$option" == 'start_measurement' && $# -lt 19 ]]; then
    echo "Error: Insufficient arguments provided. Listing supplied arguments:"
    for arg in "$@"; do
      echo "Argument: $arg"
    done
    exit 1
fi

case $option in
  start_measurement)
    start_measurement "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9" "${10}" "${11}" "${12}" "${13}" "${14}" "${15}" "${16}" "${17}" "${18}" "${19}" "${20}" "${21}"
    ;;
  lap_measurement)
    lap_measurement
    ;;
  end_measurement)
    end_measurement
    ;;
esac

