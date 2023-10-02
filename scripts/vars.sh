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

    # gitlab uses this one
    # double check these values with someone 
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
  *)
    echo "Invalid option ($option). Please specify an option: cpu_vars, or add_var [key] [value]."
    exit 1
    ;;
esac