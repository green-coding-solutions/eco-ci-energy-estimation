#!/usr/bin/env bash
set -euo pipefail

get_geo_ipapi_co() {
    response=$(curl -s https://ipapi.co/json || true)

    if [[ -z "$response" ]] || ! echo "$response" | jq empty; then
        echo "Failed to retrieve data or received invalid JSON. Exiting" >&2
        return
    fi

    if echo "$response" | jq '.latitude, .longitude, .city' | grep -q null; then
        echo -e "Required data is missing\nResponse is ${response}\nExiting" >&2
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
        echo "Required carbonIntensity is missing.\nResponse is ${response}\nExiting" >&2
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
        latitude=$(echo "$geo_data" | jq '.latitude')
        longitude=$(echo "$geo_data" | jq '.longitude')
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
  echo "No option provided. Please specify an option to misc.sh"
  exit 1
fi

option="$1"
case $option in
  get_energy_co2)
    get_energy_co2_val $2
    ;;
  get_embodied_co2)
    get_embodied_co2_val $2
    ;;
  *)
    echo "Invalid option ($option). Please specify a valid option to misc.sh"
    exit 1
    ;;
esac