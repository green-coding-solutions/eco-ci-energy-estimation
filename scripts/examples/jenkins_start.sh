#!/usr/bin/env bash
set -euo pipefail

shell=bash

ECO_CI_SEND_DATA='true' # turn this off if you do not want to use the web dashboard on https://metrics.green-coding.io

# If you want filter data in the GMT Dashboard or in CarbonDB you can here manually set data for drill-down later
# The values given are just some default recommendations
ECO_CI_FILTER_TYPE='machine.ci'
ECO_CI_FILTER_PROJECT='CI/CD'
ECO_CI_FILTER_MACHINE='local-runner'
ECO_CI_FILTER_TAGS='' # Tags must be comma separated. Tags cannot have commas itself or contain quotes

ECO_CI_CO2_CALCULATION_METHOD="constant"
ECO_CI_CO2_GRID_INTENSITY_CONSTANT=334 # for Germany in 2024 from https://app.electricitymaps.com/zone/DE/all/yearly
ECO_CI_CO2_GRID_INTENSITY_API_TOKEN=""

ECO_CI_JSON_OUTPUT='true'

# Change this to a local installation of the GMT if you have
ECO_CI_API_ENDPOINT_ADD='https://api.green-coding.io/v2/ci/measurement/add'
ECO_CI_API_BADGE_GET='https://api.green-coding.io/v1/ci/badge/get'
ECO_CI_DASHBOARD_URL='https://metrics.green-coding.io'
ECO_CI_GMT_API_TOKEN=''

ECO_CI_BRANCH=${GIT_BRANCH:-}
ECO_CI_GIT_URL=${GIT_URL:-}
ECO_CI_COMMIT=${GIT_COMMIT:-}

# Important:
# Use a generated power curve from Cloud Energy here
# default.sh is only a generic power profile
# See README.md how to generate a power profile
ECO_CI_MACHINE_POWER_DATA="default.sh"

$shell "$(dirname "$0")/../setup.sh" start_measurement "$ECO_CI_MACHINE_POWER_DATA" "$BUILD_ID" "$ECO_CI_BRANCH" "$ECO_CI_GIT_URL" "$JOB_URL" "$JOB_NAME" "$ECO_CI_COMMIT" "Jenkins" "$ECO_CI_SEND_DATA" "$ECO_CI_FILTER_TYPE" "$ECO_CI_FILTER_PROJECT" "$ECO_CI_FILTER_MACHINE" "$ECO_CI_FILTER_TAGS" "$ECO_CI_CO2_CALCULATION_METHOD" "$ECO_CI_CO2_GRID_INTENSITY_CONSTANT" "$ECO_CI_CO2_GRID_INTENSITY_API_TOKEN" "$ECO_CI_GMT_API_TOKEN" "$ECO_CI_JSON_OUTPUT" "$ECO_CI_API_ENDPOINT_ADD" "$ECO_CI_API_BADGE_GET" "$ECO_CI_DASHBOARD_URL"
