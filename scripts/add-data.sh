#!/usr/bin/env bash
set -euo pipefail

function create_json_file() {
    file="$1"
    label="$2"
    cpu="$3"
    energy="$4"
    power="$5"
    time="$6"

    # Check if the JSON file exists, and create it if not
    if [ ! -f "$file" ]; then
        echo "{}" > "$file"
    fi

    # Define the data point to add to the JSON file
    NEW_STEP=$(cat <<EOM
    {
        "label": "$label",
        "cpu_avg_percent": "$cpu",
        "energy_joules": "$energy",
        "power_avg_watts": "$power",
        "time": "$time"
    }
EOM
    )

    # Add the data point to the JSON file
    if [ -s "$file" ]; then
        jq --argjson newstep "$NEW_STEP" '. + $newstep' "$file" > /tmp/eco-ci/tmp.$$.json && mv /tmp/eco-ci/tmp.$$.json "$file"
    else
        echo "$NEW_STEP" > "$file"
    fi

    # Remove all line breaks
    tr -d '\n' < "$file" > /tmp/eco-ci/temp-lap-data.json && mv /tmp/eco-ci/temp-lap-data.json "$file"

}

option="$1"
case $option in
  create_json_file)
    create_json_file "$2" "$3" "$4" "$5" "$6" "$7"
    ;;
esac
