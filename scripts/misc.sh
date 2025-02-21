#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/vars.sh"

get_geoip() {
    response=$(curl -s https://ipapi.co/json || true)

    if [[ -z "$response" ]] || ! echo "$response" | jq empty; then
        echo "Failed to retrieve data or received invalid JSON. Exiting" >&2
        return
    fi

    if echo "$response" | jq '.latitude, .longitude, .city, .ip' | grep -q null; then
        echo -e "Required data is missing\nResponse is ${response}\nExiting" >&2
        return
    fi

    latitude=$(echo "$response" | jq '.latitude')
    longitude=$(echo "$response" | jq '.longitude')
    city=$(echo "$response" | jq -r '.city')
    ip=$(echo "$response" | jq -r '.ip')
    start_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    add_var 'ECO_CI_GEO_CITY' "$city"
    add_var 'ECO_CI_GEO_LAT' "$latitude"
    add_var 'ECO_CI_GEO_LON' "$longitude"
    add_var 'ECO_CI_GEO_IP' "$ip"
    add_var 'START_TIME' "$start_time"
}

get_carbon_intensity() {
    if [ -z "${ECO_CI_ELECTRICITYMAPS_API_TOKEN+x}" ]; then
        export ECO_CI_ELECTRICITYMAPS_API_TOKEN='no_token'
    fi

    ECO_CI_GEO_LAT=${ECO_CI_GEO_LAT:-}
    ECO_CI_GEO_LON=${ECO_CI_GEO_LON:-}

    response=$(curl -s -H "auth-token: ${ECO_CI_ELECTRICITYMAPS_API_TOKEN}" "https://api.electricitymap.org/v3/carbon-intensity/latest?lat=${ECO_CI_GEO_LAT}&lon=${ECO_CI_GEO_LON}" || true)

    if [[ -z "$response" ]] || ! echo "$response" | jq empty; then
        echo 'Failed to retrieve data or received invalid JSON. Exiting' >&2
        return
    fi

    if echo "$response" | jq '.carbonIntensity' | grep -q null; then
        echo "Required carbonIntensity is missing.\nResponse is ${response}\nExiting" >&2
        return
    fi

    co2_intensity=$(echo "$response" | jq '.carbonIntensity')

    echo "Carbon intensity from Electricitymaps is ${co2_intensity}"
    add_var 'ECO_CI_CO2I' "$co2_intensity"
}

get_minimum_carbon_intensity() {
    #This gives the minimum carbon intensity in the last 24 hours. This is the best estimate we have access to 
    #for finding how much carbon can be reduced in 24 hours
    if [ -z "${ECO_CI_ELECTRICITYMAPS_API_TOKEN+x}" ]; then
        export ECO_CI_ELECTRICITYMAPS_API_TOKEN='no_token'
    fi

    ECO_CI_GEO_LAT=${ECO_CI_GEO_LAT:-}
    ECO_CI_GEO_LON=${ECO_CI_GEO_LON:-}

    response=$(curl -s -H "auth-token: ${ECO_CI_ELECTRICITYMAPS_API_TOKEN}" "https://api.electricitymap.org/v3/carbon-intensity/history?lat=${ECO_CI_GEO_LAT}&lon=${ECO_CI_GEO_LON}" || true)

    if [[ -z "$response" ]] || ! echo "$response" | jq empty; then
        echo 'Failed to retrieve data or received invalid JSON. Exiting' >&2
        return
    fi

    # Gather all carbonIntensity values in history, then find the minimum
    min_co2_intensity=$(echo "$response" | jq '[.history[].carbonIntensity] | min')

    if [ -z "$min_co2_intensity" ] || [ "$min_co2_intensity" = "null" ]; then
        echo "Failed to find a valid minimum carbon intensity.
Response: ${response}
Exiting" >&2
        return
    fi

    echo "Minimum carbon intensity in last 24 hours from Electricitymaps is ${min_co2_intensity}"
    add_var 'ECO_CI_CO2I_MIN' "$min_co2_intensity"
}


get_embodied_co2 (){
    time="$1"

    ECO_CI_SCI_M=${ECO_CI_SCI_M:-}
    if [ -n "$ECO_CI_SCI_M" ]; then
        co2_value=$(echo "${ECO_CI_SCI_M} ${time} ${ECO_CI_SCI_USAGE_DURATION}" | awk '{ printf "%.9f", $1 * ( $2 / $3 ) }')
        export ECO_CI_CO2EQ_EMBODIED="$co2_value"
    else
        echo 'ECO_CI_SCI_M was not set' >&2
    fi

}

get_energy_co2 (){
    total_energy="$1"

    ECO_CI_CO2I=${ECO_CI_CO2I:-}

    if [[ -n "$ECO_CI_CO2I" ]]; then

        value_mJ=$(echo "${total_energy} 1000" | awk '{printf "%.9f", $1 * $2}' | cut -d '.' -f 1)
        value_kWh=$(echo "${value_mJ} 1e-9" | awk '{printf "%.9f", $1 * $2}')
        co2_value=$(echo "${value_kWh} ${ECO_CI_CO2I}" | awk '{printf "%.9f", $1 * $2}')

        add_var 'ECO_CI_CO2EQ_ENERGY' "$co2_value"

    else
        echo "Failed to get carbon intensity data." >&2
    fi

}
