#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/vars.sh"

get_geoip() {
    if [ -n "${IP2LOCATIONIO_API_KEY}" ]; then
        echo "Detected IP2Location.io API Key, will use IP2Location.io API key now."
        http_code=$(curl -s -w "%{http_code}" -o /tmp/response_body.txt https://api.ip2location.io/?key=$IP2LOCATIONIO_API_KEY)
        response=$(< /tmp/response_body.txt)
        rm /tmp/response_body.txt
        if echo "$response" | jq '.latitude, .longitude, .city_name, .ip' | grep -q null; then
            echo -e "Required data is missing\nResponse is ${response}\nExiting" >&2
            return
        fi
        response=$(echo "$response" | jq '. | .city = .city_name | del(.city_name)')
        echo "$response"
    else
        http_code=$(curl -s -w "%{http_code}" -o /tmp/response_body.txt https://ipapi.co/json)
        response=$(< /tmp/response_body.txt)
        rm /tmp/response_body.txt
        echo "$response"

        if [[ "$http_code" == "429" ]]; then
            http_code=$(curl -s -w "%{http_code}" -o /tmp/response_body.txt https://api.ip2location.io/)
            response=$(< /tmp/response_body.txt)
            rm /tmp/response_body.txt
            if echo "$response" | jq '.latitude, .longitude, .city_name, .ip' | grep -q null; then
                echo -e "Required data is missing\nResponse is ${response}\nExiting" >&2
                return
            fi
            response=$(echo "$response" | jq '. | .city = .city_name | del(.city_name)')
        fi
    fi

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

    add_var GEO_CITY "$city"
    add_var GEO_LAT "$latitude"
    add_var GEO_LON "$longitude"
    add_var GEO_IP "$ip"
}

get_carbon_intensity() {
    if [ -z "${ELECTRICITY_MAPS_TOKEN+x}" ]; then
        export ELECTRICITY_MAPS_TOKEN='no_token'
    fi

    GEO_LAT=${GEO_LAT:-}
    GEO_LON=${GEO_LON:-}

    response=$(curl -s -H "auth-token: $ELECTRICITY_MAPS_TOKEN" "https://api.electricitymap.org/v3/carbon-intensity/latest?lat=$GEO_LAT&lon=$GEO_LON" || true)

    if [[ -z "$response" ]] || ! echo "$response" | jq empty; then
        echo "Failed to retrieve data or received invalid JSON. Exiting" >&2
        return
    fi

    if echo "$response" | jq '.carbonIntensity' | grep -q null; then
        echo "Required carbonIntensity is missing.\nResponse is ${response}\nExiting" >&2
        return
    fi

    co2_intensity=$(echo "$response" | jq '.carbonIntensity')

    add_var CO2I "$co2_intensity"
}

get_embodied_co2 (){
    time="$1"

    SCI_M=${SCI_M:-}
    if [ -n "$SCI_M" ]; then
        co2_value=$(echo "$SCI_M $time $SCI_USAGE_DURATION" | awk '{ printf "%.9f", $1 * ( $2 / $3 ) }')
        export CO2EQ_EMBODIED="$co2_value"
    else
        echo "SCI_M was not set" >&2
    fi

}

get_energy_co2 (){
    total_energy="$1"

    CO2I=${CO2I:-}

    if [[ -n "$CO2I" ]]; then

        value_mJ=$(echo "$total_energy 1000" | awk '{printf "%.9f", $1 * $2}' | cut -d '.' -f 1)
        value_kWh=$(echo "$value_mJ 1e-9" | awk '{printf "%.9f", $1 * $2}')
        co2_value=$(echo "$value_kWh $CO2I" | awk '{printf "%.9f", $1 * $2}')

        add_var CO2EQ_ENERGY "$co2_value"

    else
        echo "Failed to get carbon intensity data." >&2
    fi

}
