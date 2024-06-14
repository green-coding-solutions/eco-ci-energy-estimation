#!/usr/bin/env bash
set -euo pipefail

FILE=""
REPOSITORY=""
BRANCH=""
WORKFLOW=""
RUN_ID=""

# Parse named parameters
while [[ $# -gt 0 ]]; do
    key="$1"

    case $key in
        -f|--file)
        FILE="$2"
        shift # past argument
        shift # past value
        ;;
        --repository)
        REPOSITORY="$2"
        shift # past argument
        shift # past value
        ;;
        --branch)
        BRANCH="$2"
        shift # past argument
        shift # past value
        ;;
        --workflow)
        WORKFLOW="$2"
        shift # past argument
        shift # past value
        ;;
        --run_id)
        RUN_ID="$2"
        shift # past argument
        shift # past value
        ;;
        *)  # unknown option
        echo "Unknown option: $1"
        exit 1
        ;;
    esac
done

# Create the JSON file
cat > "$FILE" << EOF
{
    "repository": "$REPOSITORY",
    "branch": "$BRANCH",
    "workflow": "$WORKFLOW",
    "run_id": "$RUN_ID"
}
EOF

# Remove all line breaks
tr -d '\n' < "$FILE" > /tmp/eco-ci/temp-lap-data.json && mv /tmp/eco-ci/temp-lap-data.json "$FILE"
