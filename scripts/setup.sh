#!/bin/bash
set -euo pipefail

# Call the function to read and set the variables
source "$(dirname "$0")/vars.sh" read_vars

function initialize {
    if [[ $reset == true ]]; then
        if [[ -d /tmp/eco-ci ]]; then
          rm -rf /tmp/eco-ci
        fi
        mkdir /tmp/eco-ci
    fi
    
    git clone --depth 1 --single-branch --branch main https://github.com/green-coding-berlin/spec-power-model /tmp/eco-ci/spec-power-model

    ## Reimplement ascii graph when we find a better library
    # install go ascii
    
    if [[ $install_go == true ]]; then
        # || true here because this line technically fails with:
            # no required module provides package github.com/guptarohit/asciigraph/cmd/asciigraph: go.mod file not found in current directory or any parent directory; see 'go help modules'
        # the solution would be either to `go mod init` to create a go.mod file for this directory... but are not making a go package here so this doesn't seem appropriate
        # the other solution would be to set the environment variable `go env -w GO111MODULE=auto`... but I can't seem to get any already-set value ahead of time reliably, and do not want to overwrite
        # any user environment settings.
        # So, we ignore this error for now, as functionally the asciigraph still is installed and works for Eco-CI
        go install github.com/guptarohit/asciigraph/cmd/asciigraph@latest || true
        ascii_graph_path=$(go list -f '{{.Target}}' github.com/guptarohit/asciigraph/cmd/asciigraph) || true
        echo $ascii_graph_path
    fi

    # check for gcc
    if ! command -v gcc &> /dev/null
    then
        echo "gcc could not be found, please install it"
        exit
    fi

    # compile
    gcc /tmp/eco-ci/spec-power-model/demo-reporter/cpu-utilization.c -o /tmp/eco-ci/demo-reporter

}


function setup_python {
    # Create a venv, and backup old
    python3 -m venv /tmp/eco-ci/venv

    if [[ $VIRTUAL_ENV != '' ]]; then
       $PREVIOUS_VENV=$VIRTUAL_ENV
       source "$(dirname "$0")/vars.sh" add_var PREVIOUS_VENV $PREVIOUS_VENV
    fi

    #  Installing requirements
    # first activate our venv
    source /tmp/eco-ci/venv/bin/activate
    python3 -m pip install -r /tmp/eco-ci/spec-power-model/requirements.txt
    # now reset to old venv
    deactivate our venv
    # reactivate the old one, if it was present
    if [[ $PREVIOUS_VENV != '' ]]; then
      source $PREVIOUS_VENV/bin/activate
    fi
}

function start_measurement {
    # call init_variables
    source "$(dirname "$0")/vars.sh" cpu_vars

    source "$(dirname "$0")/vars.sh" add_var API_BASE "https://api.green-coding.berlin"
    source "$(dirname "$0")/vars.sh" add_var INIT "DONE"

    # start measurement
    killall -9 -q /tmp/eco-ci/demo-reporter || true
    /tmp/eco-ci/demo-reporter | tee -a /tmp/eco-ci/cpu-util-total.txt > /tmp/eco-ci/cpu-util.txt &
    # start a timer
    date +%s > /tmp/eco-ci/timer.txt
    date +%s > /tmp/eco-ci/timer-total.txt
}

# Main script logic
if [ $# -eq 0 ]; then
  echo "No option provided. Please specify an option: initialize, setup_python, or start_measurement."
  exit 1
fi


option="$1"

case $option in
  initialize)
    func=initialize
    ;;
  setup_python)
    func=setup_python
    ;;
  start_measurement)
    func=start_measurement
    ;;
  *)
    echo "Invalid option. Please specify an option: initialize, setup_python, or start_measurement."
    exit 1
    ;;
esac

install_go=true
reset=true

while [[ $# -gt 1 ]]; do
    opt="$2"

    case $opt in
        -g|--go) 
        install_go=$3
        shift
        ;;
        -r|--reset) 
        reset=$3
        shift
        ;;
        \?) echo "Invalid option -$2" >&2
        ;;
    esac
    shift
done

if [[ $func == initialize ]]; then
    initialize
elif [[ $func == setup_python ]]; then
    setup_python
elif [[ $func == start_measurement ]]; then
    start_measurement
fi
