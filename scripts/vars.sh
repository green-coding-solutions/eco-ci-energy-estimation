#!/bin/bash
set -euo pipefail

model_name=$(cat /proc/cpuinfo  | grep "model name")

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
    if [[ "$model_name" == *"8272CL"* ]]; then
        echo "Found 8272CL model"
        add_var "MODEL_NAME" "8272CL";

        add_var "TDP" 195;
        add_var "CPU_THREADS" 52;
        add_var "CPU_CORES" 26;
        add_var "CPU_MAKE" "intel";
        add_var "RELEASE_YEAR" 2019;
        add_var "RAM" 182;
        add_var "CPU_FREQ" 2600;
        add_var "CPU_CHIPS" 1;
        add_var "VHOST_RATIO" $(echo "2/52" | bc -l);

    elif [[ "$model_name" == *"8370C"* ]]; then
        echo "Found 8370C model"
        add_var "MODEL_NAME" "8370C";

        add_var "TDP" 270;
        add_var "CPU_THREADS" 64;
        add_var "CPU_CORES" 32;
        add_var "CPU_MAKE" "intel";
        add_var "RELEASE_YEAR" 2021;
        add_var "RAM" 224;
        add_var "CPU_FREQ" 2800;
        add_var "CPU_CHIPS" 1;
        add_var "VHOST_RATIO" $(echo "2/64" | bc -l);

    elif [[ "$model_name" == *"9880H"* ]]; then
        echo "Found 9880H model"
        add_var "MODEL_NAME" "9880H"

        add_var "TDP" 45;
        add_var "CPU_THREADS" 16;
        add_var "CPU_CORES" 8;
        add_var "CPU_MAKE" "intel";
        add_var "RELEASE_YEAR" 2019;
        add_var "RAM" 128;
        add_var "CPU_FREQ" 2300;
        add_var "CPU_CHIPS" 1;

    elif [[ "$model_name" == *"E5-2673 v4"* ]]; then
        echo "Found E5-2673 v4 model"
        add_var "MODEL_NAME" "E5-2673v4";

        add_var "TDP" 165;
        add_var "CPU_THREADS" 52;
        add_var "CPU_CORES" 26;
        add_var "CPU_MAKE" "intel";
        add_var "RELEASE_YEAR" 2018;
        add_var "RAM" 182;
        add_var "CPU_FREQ" 2300;
        add_var "CPU_CHIPS" 1;
        add_var "VHOST_RATIO" $(echo "2/52" | bc -l);

    elif [[ "$model_name" == *"E5-2673 v3"* ]]; then
        echo "Found E5-2673 v3 model"
        add_var "MODEL_NAME" "E5-2673v3";

        add_var "TDP" 110;
        add_var "CPU_THREADS" 24;
        add_var "CPU_CORES" 12;
        add_var "CPU_MAKE" "intel";
        add_var "RELEASE_YEAR" 2015;
        add_var "RAM" 84;
        add_var "CPU_FREQ" 2400;
        add_var "CPU_CHIPS" 1;
        add_var "VHOST_RATIO" $(echo "2/24" | bc -l);

    # model is underclocked
    elif [[ "$model_name" == *"8171M"* ]]; then
        echo "Found 8171M model"
        add_var "MODEL_NAME" "8171M";

        add_var "TDP" 165;
        add_var "CPU_THREADS" 52;
        add_var "CPU_CORES" 26;
        add_var "CPU_MAKE" "intel";
        add_var "RELEASE_YEAR" 2018;
        add_var "RAM" 182;
        add_var "CPU_FREQ" 2600;
        add_var "CPU_CHIPS" 1;
        add_var "VHOST_RATIO" $(echo "2/52" | bc -l);

    elif [[ "$model_name" == *"AMD EPYC 7763"* ]]; then
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

    # gitlab uses this one
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

    else
        echo "⚠️ Unknown model $model_name for estimation, running default ..." # >> $GITHUB_STEP_SUMMARY
        add_var "MODEL_NAME" "unknown";

    fi
}


get_geo_ipapi_co() {
    response=$(curl -s httpppp://ip-api.com/json/ || true)

    if echo "$response" | jq '.lat, .lon, .city' | grep -q null; then
        echo "Required data is missing. Exiting" >&2
        return 1
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

    if echo "$response" | jq '.carbonIntensity' | grep -q null; then
        echo "Required carbonIntensity is missing. Exiting" >&2
        return 1
    fi

    echo "$response" | jq '.carbonIntensity'
}

get_co2_val (){
    total_energy=$1
    geo_data=$(get_geo_ipapi_co)
    if [ $? -eq 0 ]; then
        latitude=$(echo "$geo_data" | jq '.lat')
        longitude=$(echo "$geo_data" | jq '.lon')
        city=$(echo "$geo_data" | jq -r '.city')

        export CITY="$city"
        export LAT="$latitude"
        export LON="$longitude"

        carbon_intensity=$(get_carbon_intensity $latitude $longitude)

        if [[ $? -eq 0 ]]; then
            export CO2I="$carbon_intensity"

            value_mJ=$(echo "$total_energy*1000" | bc -l | cut -d '.' -f 1)
            value_kWh=$(echo "$value_mJ * 10^-9" | bc -l)
            co2_value=$(echo "$value_kWh * $carbon_intensity" | bc -l)

            export CO2EQ="$co2_value"

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
  get_co2)
    get_co2_val $2
    ;;
  *)
    echo "Invalid option ($option). Please specify an option: cpu_vars, or add_var [key] [value]."
    exit 1
    ;;
esac