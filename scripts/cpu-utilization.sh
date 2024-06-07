#!/usr/bin/env sh
# by Paul Colby (http://colby.id.au), no rights reserved ;)
# Modified to have no integer rounding by Green Coding Solutions, no rights reserved :)

PREV_TOTAL=0
PREV_IDLE=0

while true; do
    CPU=($(sed -n 's/^cpu\s//p' /proc/stat))
    IDLE=${CPU[3]} # Just the idle CPU time.
    TIME_BEFORE=$(date +%s%N)
    TOTAL=0
    for VALUE in "${CPU[@]:0:8}"; do
        TOTAL=$((TOTAL+VALUE))
    done

    sleep 1

    TIME_AFTER=$(date +%s%N)
    DIFF_IDLE=$((IDLE-PREV_IDLE))
    DIFF_TOTAL=$((TOTAL-PREV_TOTAL))
    DIFF_USAGE=$(echo "scale=2; ((1000*(${DIFF_TOTAL}-${DIFF_IDLE})/${DIFF_TOTAL})/10)" | bc -l)
    DIFF_USAGE=$(echo $DIFF_USAGE | sed 's/^\./0&/')
    echo $(echo "scale=6; ($TIME_AFTER - $TIME_BEFORE) / 1000000000" | bc -l) "$DIFF_USAGE"

    # Remember the total and idle CPU times for the next check.
    PREV_TOTAL="$TOTAL"
    PREV_IDLE="$IDLE"

done