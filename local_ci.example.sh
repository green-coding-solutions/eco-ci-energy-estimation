#!/usr/bin/env bash
set -euo pipefail

ECO_CI_SEND_DATA="true"
ECO_CI_DISPLAY_BADGE="true"
ECO_CI_DISPLAY_TABLE="true"
ECO_CI_SHOW_CARBON="true"

ECO_CI_WORKFLOW_ID="YOUR WORKFLOW ID"

ECO_CI_COMPANY_UUID=""
ECO_CI_PROJECT_UUID=""
ECO_CI_MACHINE_UUID=""

# Please input valid UUIDs here if you want to use CarbonDB (https://www.green-coding.io/projects/carbondb/)
# Generate one here for example: https://www.freecodeformat.com/validate-uuid-guid.php
# ECO_CI_COMPANY_UUID="YOUR COMPANY UUID"
# ECO_CI_PROJECT_UUID="YOUR PROJECT UUID"
# ECO_CI_MACHINE_UUID="YOUR MACHINE UUID"

# Use a generated power curve from Cloud Energy here
MACHINE_POWER_DATA="default.sh"

# Initialize
echo "Initialize"

"$(dirname "$0")/scripts/setup.sh" initialize $MACHINE_POWER_DATA
"$(dirname "$0")/scripts/vars.sh" add_var "WORKFLOW_ID" $ECO_CI_WORKFLOW_ID
"$(dirname "$0")/scripts/setup.sh" start_measurement
echo "Duration: "$(($(date +%s) - $(cat /tmp/eco-ci/timer-total.txt)))

# Do some work
echo "Sleeping"
sleep 3s
echo "Duration: "$(($(date +%s) - $(cat /tmp/eco-ci/timer-total.txt)))


"$(dirname "$0")/scripts/make_measurement.sh" \
-l "Step sleep" \
-r "My Pipeline ID" \
-b "Branch Name" \
-R "Repo Name" \
-c "Commit SHA hash" \
-sd "$ECO_CI_SEND_DATA" \
-s "local" \
-n "Workflow nice name" \
-cbc "$ECO_CI_COMPANY_UUID" \
-cbp "$ECO_CI_PROJECT_UUID" \
-cbm "$ECO_CI_MACHINE_UUID"

# Do some other work
echo "ls -alhR"
timeout 3s ls -alhR / > /dev/null || true
echo "Duration: "$(($(date +%s) - $(cat /tmp/eco-ci/timer-total.txt)))

echo "Sleeping "
sleep 3
echo "Duration: "$(($(date +%s) - $(cat /tmp/eco-ci/timer-total.txt)))

"$(dirname "$0")/scripts/make_measurement.sh" \
-l "Step ls -alh" \
-r "My Pipeline ID" \
-b "Branch Name" \
-R "Repo Name" \
-c "Commit SHA hash" \
-sd "$ECO_CI_SEND_DATA" \
-s "local" \
-n "Workflow nice name" \
-cbc "$ECO_CI_COMPANY_UUID" \
-cbp "$ECO_CI_PROJECT_UUID" \
-cbm "$ECO_CI_MACHINE_UUID"

echo "Display Results"
echo "Duration: "$(($(date +%s) - $(cat /tmp/eco-ci/timer-total.txt)))

# Display results
ECO_CI_FORMAT_CLR="\e[44m"
ECO_CI_TXT_CLEAR="\e[0m"

echo "Dump files"
cat /tmp/eco-ci/energy-total.txt
cat /tmp/eco-ci/cpu-util-total.txt


"$(dirname "$0")/scripts/display_results.sh" \
    -b "Branch Name" \
    -db "$ECO_CI_DISPLAY_BADGE" \
    -r "My Pipeline ID" \
    -R "Repo Name" \
    -dt "$ECO_CI_DISPLAY_TABLE" \
    -sd "$ECO_CI_SEND_DATA" \
    -s "local" \
    -sc "$ECO_CI_SHOW_CARBON"

echo -e "$ECO_CI_FORMAT_CLR$(cat /tmp/eco-ci/output.txt)$ECO_CI_TXT_CLEAR"
echo "Duration: "$(($(date +%s) - $(cat /tmp/eco-ci/timer-total.txt)))

"$(dirname "$0")/scripts/setup.sh" end_measurement

