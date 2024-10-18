#!/usr/bin/env bash
set -euo pipefail

shell=bash

ECO_CI_SEND_DATA='true'
ECO_CI_DISPLAY_BADGE='true'
ECO_CI_DISPLAY_TABLE='true'

ECO_CI_WORKFLOW_ID='YOUR WORKFLOW ID'

# If you want filter data in the GMT Dashboard or in CarbonDB you can here manually set data for drill-down later
# The values given are just some default recommendations
ECO_CI_FILTER_TYPE=''
ECO_CI_FILTER_PROJECT='CI/CD'
ECO_CI_FILTER_MACHINE='local-runner'
ECO_CI_FILTER_TAGS='' # Tags must be comma separated. Tags cannot have commas itself or contain quotes

ECO_CI_CALCULATE_CO2='true'
ECO_CI_JSON_OUTPUT='true'

# Change this to a local installation of the GMT if you have
ECO_CI_API_ENDPOINT_ADD='https://api.green-coding.io/v2/ci/measurement/add'
ECO_CI_API_BADGE_GET='https://api.green-coding.io/v1/ci/badge/get'

# Use a generated power curve from Cloud Energy here
ECO_CI_MACHINE_POWER_DATA="default.sh"

# Initialize
echo "Initialize"

$shell "$(dirname "$0")/scripts/setup.sh" start_measurement "$ECO_CI_MACHINE_POWER_DATA" "MY_RUN_ID" "NO_BRANCH" "LOCAL_TEST_REPO" "$ECO_CI_WORKFLOW_ID" "MY WORKFLOW NAME" "NO SHA" "local" "$ECO_CI_SEND_DATA" "$ECO_CI_FILTER_TYPE" "$ECO_CI_FILTER_PROJECT" "$ECO_CI_FILTER_MACHINE" "$ECO_CI_FILTER_TAGS" "$ECO_CI_CALCULATE_CO2" "$ECO_CI_JSON_OUTPUT" "$ECO_CI_API_ENDPOINT_ADD" "$ECO_CI_API_BADGE_GET"

echo "Duration: "$(($(date +%s) - $(cat /tmp/eco-ci/timer-total.txt)))

# Do some work
echo "Sleeping"
sleep 2s
echo "Duration: "$(($(date +%s) - $(cat /tmp/eco-ci/timer-total.txt)))


$shell "$(dirname "$0")/scripts/make_measurement.sh" make_measurement "My_label"

# Do some other work
echo "ls -alhR"
timeout 3s ls -alhR / &> /dev/null || true
echo "Duration: "$(($(date +%s) - $(cat /tmp/eco-ci/timer-total.txt)))

echo "Sleeping "
sleep 1
echo "Duration: "$(($(date +%s) - $(cat /tmp/eco-ci/timer-total.txt)))

$shell "$(dirname "$0")/scripts/make_measurement.sh" make_measurement "other label"
#"My other label"

echo "Display Results"
echo "Duration: "$(($(date +%s) - $(cat /tmp/eco-ci/timer-total.txt)))

# Display results
ECO_CI_FORMAT_CLR="\e[44m"
ECO_CI_TXT_CLEAR="\e[0m"

echo "Dump files"
cat /tmp/eco-ci/energy-step.txt
cat /tmp/eco-ci/cpu-util-step.txt
cat /tmp/eco-ci/energy-total.txt
cat /tmp/eco-ci/cpu-util-total.txt

$shell "$(dirname "$0")/scripts/display_results.sh" display_results $ECO_CI_DISPLAY_TABLE $ECO_CI_DISPLAY_BADGE

if [[ "$ECO_CI_JSON_OUTPUT" == 'true' ]]; then
    echo "JSON Dump:"
   cat /tmp/eco-ci/lap-data.json
   cat /tmp/eco-ci/total-data.json
fi

echo -e "\n"
echo -e "$ECO_CI_FORMAT_CLR$(cat /tmp/eco-ci/output.txt)$ECO_CI_TXT_CLEAR"
echo "Duration: "$(($(date +%s) - $(cat /tmp/eco-ci/timer-total.txt)))

$shell "$(dirname "$0")/scripts/setup.sh" end_measurement

