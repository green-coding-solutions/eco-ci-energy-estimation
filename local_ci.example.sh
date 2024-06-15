#!/usr/bin/env bash
set -euo pipefail

shell=bash

ECO_CI_SEND_DATA="true"
ECO_CI_DISPLAY_BADGE="true"
ECO_CI_DISPLAY_TABLE="true"

ECO_CI_WORKFLOW_ID="YOUR WORKFLOW ID"

ECO_CI_COMPANY_UUID=""
ECO_CI_PROJECT_UUID=""
ECO_CI_MACHINE_UUID=""

CALCULATE_CO2="true"
JSON_OUTPUT="true"

# Please input valid UUIDs here if you want to use CarbonDB (https://www.green-coding.io/projects/carbondb/)
# Generate one here for example: https://www.freecodeformat.com/validate-uuid-guid.php
# ECO_CI_COMPANY_UUID="YOUR COMPANY UUID"
# ECO_CI_PROJECT_UUID="YOUR PROJECT UUID"
# ECO_CI_MACHINE_UUID="YOUR MACHINE UUID"

# Use a generated power curve from Cloud Energy here
MACHINE_POWER_DATA="default.sh"

# Initialize
echo "Initialize"

$shell "$(dirname "$0")/scripts/setup.sh" start_measurement "$MACHINE_POWER_DATA" "MY_RUN_ID" "NO_BRANCH" "LOCAL_TEST_REPO" "$ECO_CI_WORKFLOW_ID" "MY_WORKFLOW_NAME" "NO SHA" "local" "$ECO_CI_SEND_DATA" "$ECO_CI_COMPANY_UUID" "$ECO_CI_PROJECT_UUID" "$ECO_CI_MACHINE_UUID" "$CALCULATE_CO2" "$JSON_OUTPUT"

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

echo -e "$ECO_CI_FORMAT_CLR$(cat /tmp/eco-ci/output.txt)$ECO_CI_TXT_CLEAR"
echo "Duration: "$(($(date +%s) - $(cat /tmp/eco-ci/timer-total.txt)))

$shell "$(dirname "$0")/scripts/setup.sh" end_measurement

