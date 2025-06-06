#!/usr/bin/env bash
set -euo pipefail

shell=bash

ECO_CI_SEND_DATA='false'
ECO_CI_DISPLAY_BADGE='true'
ECO_CI_DISPLAY_TABLE='true'

ECO_CI_WORKFLOW_ID='YOUR_WORKFLOW_ID'
ECO_CI_SOURCE='local'

# If you want filter data in the GMT Dashboard or in CarbonDB you can here manually set data for drill-down later
# The values given are just some default recommendations
ECO_CI_FILTER_TYPE='machine.ci'
ECO_CI_FILTER_PROJECT='CI/CD'
ECO_CI_FILTER_MACHINE='local-runner'
ECO_CI_FILTER_TAGS='32131",asd' # Tags must be comma separated. Tags cannot have commas itself or contain quotes

ECO_CI_CO2_CALCULATION_METHOD="constant"
ECO_CI_CO2_GRID_INTENSITY_CONSTANT=334 # for Germany in 2024 from https://app.electricitymaps.com/zone/DE/all/yearly
ECO_CI_CO2_GRID_INTENSITY_API_TOKEN=""

ECO_CI_JSON_OUTPUT='true'


# Change this to a local installation of the GMT if you have
ECO_CI_API_ENDPOINT_ADD='http://api.green-coding.internal:9142/v2/ci/measurement/add'
ECO_CI_API_BADGE_GET='http://api.green-coding.internal:9142/v1/ci/badge/get'
ECO_CI_DASHBOARD_URL='http://metrics.green-coding.internal:9142'
ECO_CI_GMT_API_TOKEN=''

# Use a generated power curve from Cloud Energy here
ECO_CI_MACHINE_POWER_DATA="macos-14-mac-mini-m1.sh"

function dump_raw_measurement_data() {
    wc -l /tmp/eco-ci/cpu-util-temp.txt
    echo /tmp/eco-ci/cpu-util-temp.txt
    cat /tmp/eco-ci/cpu-util-temp.txt

    echo "---------------------"
    wc -l /tmp/eco-ci/cpu-util-step.txt
    echo /tmp/eco-ci/cpu-util-step.txt
    cat /tmp/eco-ci/cpu-util-step.txt

    echo "---------------------"
    wc -l /tmp/eco-ci/energy-step.txt
    echo /tmp/eco-ci/energy-step.txt
    cat /tmp/eco-ci/energy-step.txt

    echo "---------------------"
    wc -l /tmp/eco-ci/cpu-util-total.txt
    echo /tmp/eco-ci/cpu-util-total.txt
    cat /tmp/eco-ci/cpu-util-total.txt

    echo "---------------------"
    wc -l /tmp/eco-ci/energy-total.txt
    echo /tmp/eco-ci/energy-total.txt
    cat /tmp/eco-ci/energy-total.txt
}


# START OF WORKFLOW

# Initialize
echo "Initialize"

$shell "$(dirname "$0")/../setup.sh" start_measurement "$ECO_CI_MACHINE_POWER_DATA" "MY_RUN_ID" "NO_BRANCH" "LOCAL_TEST_REPO" "$ECO_CI_WORKFLOW_ID" "MY WORKFLOW NAME" "NO SHA" $ECO_CI_SOURCE "$ECO_CI_SEND_DATA" "$ECO_CI_FILTER_TYPE" "$ECO_CI_FILTER_PROJECT" "$ECO_CI_FILTER_MACHINE" "$ECO_CI_FILTER_TAGS" "$ECO_CI_CO2_CALCULATION_METHOD" "$ECO_CI_CO2_GRID_INTENSITY_CONSTANT" "$ECO_CI_CO2_GRID_INTENSITY_API_TOKEN" "$ECO_CI_GMT_API_TOKEN" "$ECO_CI_JSON_OUTPUT" "$ECO_CI_API_ENDPOINT_ADD" "$ECO_CI_API_BADGE_GET" "$ECO_CI_DASHBOARD_URL"

echo "Duration: "$(($(date "+%s%6N") - $(cat /tmp/eco-ci/timer-total.txt))) "us"

# Do some work
echo "Sleeping"
sleep 2s
echo "Duration: "$(($(date "+%s%6N") - $(cat /tmp/eco-ci/timer-total.txt))) "us"
dump_raw_measurement_data

$shell "$(dirname "$0")/../make_measurement.sh" make_measurement "My_label"
dump_raw_measurement_data

# Do some other work
echo "ls -alhR"
timeout 3s ls -alhR / &> /dev/null || true
echo "Duration: "$(($(date "+%s%6N") - $(cat /tmp/eco-ci/timer-total.txt))) "us"

echo "Sleeping "
sleep 1
echo "Duration: "$(($(date "+%s%6N") - $(cat /tmp/eco-ci/timer-total.txt))) "us"

$shell "$(dirname "$0")/../make_measurement.sh" make_measurement "other label"
echo "Dump raw measurement data"
dump_raw_measurement_data

echo "Display Results"
echo "Duration: "$(($(date "+%s%6N") - $(cat /tmp/eco-ci/timer-total.txt))) "us"

# Display results
ECO_CI_FORMAT_CLR="\e[44m"
ECO_CI_TXT_CLEAR="\e[0m"

$shell "$(dirname "$0")/../display_results.sh" display_results $ECO_CI_DISPLAY_TABLE $ECO_CI_DISPLAY_BADGE

if [[ "$ECO_CI_JSON_OUTPUT" == 'true' ]]; then
    echo "JSON Dump:"
   cat /tmp/eco-ci/lap-data.json
fi

echo -e "\n"
echo -e "$ECO_CI_FORMAT_CLR$(cat /tmp/eco-ci/output.txt)$ECO_CI_TXT_CLEAR"
echo "Duration: "$(($(date "+%s%6N") - $(cat /tmp/eco-ci/timer-total.txt))) "us"

$shell "$(dirname "$0")/../setup.sh" end_measurement
