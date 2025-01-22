#!/usr/bin/env bash
set -euo pipefail

shell=bash

# Display results
ECO_CI_FORMAT_CLR="\e[44m"
ECO_CI_TXT_CLEAR="\e[0m"

ECO_CI_DISPLAY_BADGE='true'
ECO_CI_DISPLAY_TABLE='true'
ECO_CI_JSON_OUTPUT='true' # must be set again here and should be identical to jenkins_start

$shell "$(dirname "$0")/../display_results.sh" display_results $ECO_CI_DISPLAY_TABLE $ECO_CI_DISPLAY_BADGE

if [[ "$ECO_CI_JSON_OUTPUT" == 'true' ]]; then
    echo "JSON Dump:"
   cat /tmp/eco-ci/lap-data.json
   cat /tmp/eco-ci/total-data.json
fi

echo -e "\n"
echo -e "$ECO_CI_FORMAT_CLR$(cat /tmp/eco-ci/output.txt)$ECO_CI_TXT_CLEAR"

$shell "$(dirname "$0")/../setup.sh" end_measurement