#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/vars.sh"
read_vars

function create_json_file() {
    file="$1"

    run_id_enc=$( echo ${RUN_ID} | jq -Rr @uri)
    workflow_id_enc=$( echo ${WORKFLOW_ID} | jq -Rr @uri)
    branch_enc=$( echo ${BRANCH} | jq -Rr @uri)
    repo_enc=$( echo ${REPOSITORY} | jq -Rr @uri)

    cat > "$file" << EOF
    {
        "repository": "$repo_enc",
        "branch": "$branch_enc",
        "workflow": "$workflow_id_enc",
        "run_id": "$run_id_enc"
    }
EOF

    # Remove all line breaks
    tr -d '\n' < "$file" > /tmp/eco-ci/temp-lap-data.json && mv /tmp/eco-ci/temp-lap-data.json "$file"
}

option="$1"
case $option in
  create_json_file)
    create_json_file "$2"
    ;;
esac
