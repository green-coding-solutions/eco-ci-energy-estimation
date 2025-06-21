#!/usr/bin/env bash
set -euo pipefail

# Import vars funtions.
# Other than in the other files we do NOT read the vars, bc we do not read them in this file
# Rather we must initialize them
source "$(dirname "$0")/vars.sh"

# takes argument machine_power_data = $1
function start_measurement {
    if [[ -d /tmp/eco-ci ]]; then
      rm -rf /tmp/eco-ci
    fi
    mkdir -p "/tmp/eco-ci"

    initialize_vars

    # check if date returns a timestamp accurate to microseconds (16 digits)
    # if not probably coreutils are missing (that's the case with alpine)
    local microseconds=$(date "+%s%6N")
    if (( ${#microseconds} < 16 )); then
      echo "ERROR: Date has returned a timestamp that is not accurate to microseconds! You may need to install coreutils." >&2
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
    add_var 'ECO_CI_CO2_CALCULATION_METHOD' "${14}"
    add_var 'ECO_CI_CO2_GRID_INTENSITY_CONSTANT' "${15}"
    add_var 'ECO_CI_CO2_GRID_INTENSITY_API_TOKEN' "${16}"
    add_var 'ECO_CI_GMT_API_TOKEN' "${17}"
    add_var 'ECO_CI_JSON_OUTPUT' "${18}"
    add_var 'ECO_CI_API_ENDPOINT_ADD' "${19}"
    add_var 'ECO_CI_API_ENDPOINT_BADGE_GET' "${20}"
    add_var 'ECO_CI_DASHBOARD_URL' "${21}"

    read_vars # reload set vars

    touch /tmp/eco-ci/cpu-util-step.txt
    touch /tmp/eco-ci/cpu-util-total.txt
    touch /tmp/eco-ci/energy-step.txt
    touch /tmp/eco-ci/energy-total.txt
    touch /tmp/eco-ci/timer-step.txt

    if [[ "${ECO_CI_CO2_CALCULATION_METHOD}" == 'location-based' ]]; then
        source "$(dirname "$0")/misc.sh"
        get_geoip # will set $ECO_CI_GEO_CITY, $ECO_CI_GEO_LAT, $ECO_CI_GEO_LONG and $ECO_CI_GEO_IP
        read_vars # reload set vars
        get_carbon_intensity # will set $ECO_CI_CO2I
    elif [[ "${ECO_CI_CO2_CALCULATION_METHOD}" == 'constant' ]]; then
        echo "Using constant for CO2 grid intensity: ${ECO_CI_CO2_GRID_INTENSITY_CONSTANT}"
        add_var 'ECO_CI_CO2I' "$ECO_CI_CO2_GRID_INTENSITY_CONSTANT"
        add_var 'ECO_CI_GEO_CITY' "CONSTANT"
    else
        echo "Eco CI CO2 Calculation Method can only be constant or location based. You provided: ${ECO_CI_CO2_CALCULATION_METHOD}" >&2
        exit 1
    fi

    ##  we now save first energy data from the beginning of the function until here
    ## which will be the overhead of initialization, calling get_geoip etc.

    # Capture current cpu util file and trim trailing empty lines from the file to not run into read/write race condition later
    sed '/^[[:space:]]*$/d' /tmp/eco-ci/cpu-util-step.txt > /tmp/eco-ci/cpu-util-temp.txt

    # this measurement we purely do for the overhead calculation
    if [[ $(wc -l < /tmp/eco-ci/cpu-util-temp.txt) -gt 0 ]]; then
        source "$(dirname "$0")/make_measurement.sh"
        make_inference # will populate /tmp/eco-ci/energy-step.txt
    fi

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
        local child_pids=$(pgrep -P $parent_pid)
        kill -SIGTERM $parent_pid 2>/dev/null || true;
        for child_pid in $child_pids; do
            kill_tree $child_pid
        done
    done
}


function end_measurement {
    if [[ $(uname) == "Darwin" ]]; then
        kill_tree $(pgrep -f "$(dirname "$0")/cpu-utilization-macos.sh" || true)
    else
        # Since we call sleep in the linux script we cannot kill_tree it. It might happen that
        # sleep is a running child process which is killed and then a race condition between killing the sleep
        # and effectively continueing the script and killing the parent to abort execution happens
        pkill -SIGTERM -f "$(dirname "$0")/cpu-utilization-linux.sh"  || true;
    fi
}

option="$1"

if [[ "$option" == 'start_measurement' && $# -lt 19 ]]; then
    echo "Error: Insufficient arguments provided. Listing supplied arguments:" >&2
    for arg in "$@"; do
      echo "Argument: $arg"
    done
    exit 1
fi

case $option in
  start_measurement)
    start_measurement "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9" "${10}" "${11}" "${12}" "${13}" "${14}" "${15}" "${16}" "${17}" "${18}" "${19}" "${20}" "${21}" "${22}"
    ;;
  lap_measurement)
    lap_measurement
    ;;
  end_measurement)
    end_measurement
    ;;
esac

