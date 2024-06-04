#!/usr/bin/env bash
set -euo pipefail

#model_name=$(cat /proc/cpuinfo  | grep "model name")
model_name="unknown"

add_var() {
    key=$1
    value=$2
    file="/tmp/eco-ci/vars.json"
    #check if /tmp/eco-ci directory exists, if not make it
    if [ ! -d "/tmp/eco-ci" ]; then
        mkdir -p "/tmp/eco-ci"
    fi

    # Check if the JSON file exists
    if [ ! -f $file ]; then
        # Create a new JSON file with the key-value pair
        echo "{\"$key\": \"$value\"}" > $file
    else
        # Update or add the key-value pair in the JSON file
        # check if the key exists in the json file with jq
        if [[ $(jq ".$key" $file) == "null" ]]; then
            # add the key-value pair to the json file
            jq --arg key "$key" --arg value "$value" '. + {($key): $value}' "$file" > "/tmp/eco-ci/vars.json.tmp" && mv "/tmp/eco-ci/vars.json.tmp" "$file"
        else
            # update the key-value pair in the json file
            jq --arg key "$key" --arg value "$value" '.[$key] = $value' "$file" > "/tmp/eco-ci/vars.json.tmp" && mv "/tmp/eco-ci/vars.json.tmp" "$file"
        fi
    fi
}

read_vars() {
    dict_file="/tmp/eco-ci/vars.json"

    if [[ -f "$dict_file" ]]; then
        # Read the JSON file and extract key-value pairs
        while IFS="=" read -r key value; do
            # Trim leading/trailing whitespace and quotes from the key
            key=$(echo "$key" | sed -e 's/^"//' -e 's/"$//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

            # Trim leading/trailing whitespace and quotes from the value
            value=$(echo "$value" | sed -e 's/^"//' -e 's/"$//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

            # Set the key-value pair as an environment variable
            export "$key"="$value"
        done < <(jq -r 'to_entries[] | "\(.key)=\(.value)"' "$dict_file")
    fi
}

function cpu_vars_fill {

    # Current GitHub default (Q1/2024)
    # https://docs.github.com/en/actions/using-github-hosted-runners/about-github-hosted-runners/about-github-hosted-runners#supported-runners-and-hardware-resources
    if [[ "$model_name" == *"AMD EPYC 7763"* ]]; then
        echo "Found EPYC 7763 model";
        add_var "MODEL_NAME" "EPYC_7763";

        add_var "TDP" 280;
        add_var "CPU_THREADS" 128;
        add_var "CPU_CORES" 64;
        add_var "CPU_MAKE" "amd";
        add_var "RELEASE_YEAR" 2021;
        add_var "RAM" 512;
        add_var "CPU_FREQ" 2450;
        add_var "CPU_CHIPS" 1;
        add_var "VHOST_RATIO" $(echo "4/128" | bc -l);
        # FROM https://datavizta.boavizta.org/serversimpact
        # we assume a disk size of 448 GB total.
        # This totals to 1151.7 kg. With a 4/128 splitting this is 35,990.625 gCO2e
        add_var "SCI_M" 35990.625;
        # we use 4 years - 1*60*60*24*365*4 =
        add_var "SCI_USAGE_DURATION" 126144000

    # gitlab uses this one (Q1/2024)
    elif [[ "$model_name" == *"AMD EPYC 7B12"* ]]; then
        echo "Found EPYC 7B12 model"
        add_var "MODEL_NAME" "EPYC_7B12";

        add_var "TDP" 240;
        add_var "CPU_THREADS" 128;
        add_var "CPU_CORES" 64;
        add_var "CPU_MAKE" "amd";
        add_var "RELEASE_YEAR" 2021;
        add_var "RAM" 512;
        add_var "CPU_FREQ" 2250;
        add_var "CPU_CHIPS" 1; # see if we can find reference for this
        add_var "VHOST_RATIO" $(echo "1/64" | bc -l);
        # we assume a disk size of 1344 GB total according to https://gitlab.com/gitlab-org/gitlab-runner/-/issues/29107
        # which claims runners have 21 GB of disk space with a splitting facttor of 1/64
        # FROM https://datavizta.boavizta.org/serversimpact
        # This totals to 1173.7 kg. With a 1/64 splitting this is 18339,0625 gCO2e
        add_var "SCI_M" 18339.0625;
        # we use 4 years - 1*60*60*24*365*4 =
        add_var "SCI_USAGE_DURATION" 126144000


    else
        echo "⚠️ Unknown model $model_name for estimation, will use auto detect ..." # >> $GITHUB_STEP_SUMMARY
        # we use a default configuration here from https://datavizta.boavizta.org/serversimpact
        add_var "SCI_M" 800.3;
        # we use 4 years - 1*60*60*24*365*4 =
        add_var "SCI_USAGE_DURATION" 126144000
        add_var "MODEL_NAME" "unknown";
    fi
}


get_geo_ipapi_co() {
    response=$(curl -s http://ip-api.com/json/ || true)

    if [[ -z "$response" ]] || ! echo "$response" | jq empty; then
        echo "Failed to retrieve data or received invalid JSON. Exiting" >&2
        return
    fi

    if echo "$response" | jq '.lat, .lon, .city' | grep -q null; then
        echo "Required data is missing. Exiting" >&2
        return
    fi

    echo "$response"
}

get_carbon_intensity() {
    latitude=$1
    longitude=$2

    if [ -z "${ELECTRICITY_MAPS_TOKEN+x}" ]; then
        export ELECTRICITY_MAPS_TOKEN='no_token'
    fi

    response=$(curl -s -H "auth-token: $ELECTRICITY_MAPS_TOKEN" "https://api.electricitymap.org/v3/carbon-intensity/latest?lat=$latitude&lon=$longitude" || true)

    if [[ -z "$response" ]] || ! echo "$response" | jq empty; then
        echo "Failed to retrieve data or received invalid JSON. Exiting" >&2
        return
    fi

    if echo "$response" | jq '.carbonIntensity' | grep -q null; then
        echo "Required carbonIntensity is missing. Exiting" >&2
        return
    fi

    echo "$response" | jq '.carbonIntensity'
}

get_embodied_co2_val (){
    time=$1

    if [ -n "$SCI_M" ]; then
        co2_value=$(echo "$SCI_M * ($time/$SCI_USAGE_DURATION)" | bc -l)
        export CO2EQ_EMBODIED="$co2_value"
    else
        echo "SCI_M was not set" >&2
    fi

}

get_energy_co2_val (){
    total_energy=$1

    geo_data=$(get_geo_ipapi_co) || true
    if [ -n "$geo_data"  ]; then
        latitude=$(echo "$geo_data" | jq '.lat')
        longitude=$(echo "$geo_data" | jq '.lon')
        city=$(echo "$geo_data" | jq -r '.city')

        export CITY="$city"
        export LAT="$latitude"
        export LON="$longitude"

        carbon_intensity=$(get_carbon_intensity $latitude $longitude) || true

        if [[ -n "$carbon_intensity" ]]; then
            export CO2I="$carbon_intensity"

            value_mJ=$(echo "$total_energy*1000" | bc -l | cut -d '.' -f 1)
            value_kWh=$(echo "$value_mJ * 10^-9" | bc -l)
            co2_value=$(echo "$value_kWh * $carbon_intensity" | bc -l)

            export CO2EQ_ENERGY="$co2_value"

        else
            echo "Failed to get carbon intensity data." >&2
        fi
    else
        echo "Failed to get geolocation data." >&2
    fi
}

# Main script logic
if [ $# -eq 0 ]; then
  echo "No option provided. Please specify an option: cpu_vars, read_vars, or add_var [key] [value]."
  exit 1
fi

option="$1"
case $option in
  cpu_vars)
    cpu_vars_fill
    ;;
  add_var)
    add_var $2 "$3"
    ;;
  read_vars)
    read_vars
    ;;
  get_energy_co2)
    get_energy_co2_val $2
    ;;
  get_embodied_co2)
    get_embodied_co2_val $2
    ;;
  *)
    echo "Invalid option ($option). Please specify an option: cpu_vars, or add_var [key] [value]."
    exit 1
    ;;
esac