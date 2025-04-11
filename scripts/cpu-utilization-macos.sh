#!/usr/bin/env bash
# By ChatGPT and masterfully adapted by Arne Tarara. No rights reserved :)

iostat -w 1 -n 0 | awk -v date_cmd="gdate +%s%N" '
NR > 3 { # skips first 3 rows, which contain header data and first average-only measurement
    # Extract user, system, and idle CPU percentages
    user = $1
    sys = $2
    idle = $3

    # Calculate total CPU usage
    usage = 100 - idle

    # Get the current time in seconds with microseconds
    cmd = date_cmd
    cmd | getline current_time_ns
    close(cmd)

    # Calculate the time difference
    if (last_time_ns != "") {
        time_diff_ns = current_time_ns - last_time_ns
    } else {
        time_diff_ns = 1000000000 # No difference for the first line
    }

    # Print the time and CPU usage
    printf "%.10f %.2f\n", (time_diff_ns / 1000000000), usage

    # Store the current time as the last time for the next iteration
    last_time_ns = current_time_ns
}'