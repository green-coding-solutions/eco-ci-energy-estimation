#!/usr/bin/env bash
set -euo pipefail

shell=bash

ECO_CI_LABEL="$1"

$shell "$(dirname "$0")/../make_measurement.sh" make_measurement "${ECO_CI_LABEL}"
