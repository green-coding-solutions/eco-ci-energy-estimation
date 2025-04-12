#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/vars.sh"
read_vars

function create_json_file() {
    local file="$1"

    local run_id_enc=$( echo ${ECO_CI_RUN_ID} | jq -Rr @uri)
    local workflow_id_enc=$( echo ${ECO_CI_WORKFLOW_ID} | jq -Rr @uri)
    local branch_enc=$( echo ${ECO_CI_BRANCH} | jq -Rr @uri)
    local repo_enc=$( echo ${ECO_CI_REPOSITORY} | jq -Rr @uri)

    cat > "$file" << EOF
    {
        "repository": "${repo_enc}",
        "branch": "${branch_enc}",
        "workflow": "${workflow_id_enc}",
        "run_id": "${run_id_enc}",
        "steps" : []
    }
EOF

    # Remove all line breaks
    tr -d '\n' < "$file" > /tmp/eco-ci/temp-lap-data.json && mv /tmp/eco-ci/temp-lap-data.json "$file"
}

function add_to_json_file() {
    local file="$1"
    local label="$2"
    local cpu="$3"
    local energy="$4"
    local power="$5"
    local time="$6"

    # Define the data point to add to the JSON file
    local NEW_STEP=$(cat <<EOM
    {
        "label": "${label}",
        "cpu_avg_percent": "${cpu}",
        "energy_joules": "${energy}",
        "power_avg_watts": "${power}",
        "time": "${time}"
    }
EOM
    )

    jq --argjson newstep "$NEW_STEP" '.steps += [$newstep]' "$file" > /tmp/eco-ci/tmp.$$.json && mv /tmp/eco-ci/tmp.$$.json "$file"

    # Remove all line breaks
    tr -d '\n' < "$file" > /tmp/eco-ci/temp-lap-data.json && mv /tmp/eco-ci/temp-lap-data.json "$file"

}

option="$1"
case $option in
  create_json_file)
    create_json_file "$2"
    ;;
  add_to_json_file)
    add_to_json_file "$2" "$3" "$4" "$5" "$6" "$7"
    ;;
esac
