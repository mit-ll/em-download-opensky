#!/bin/bash
# Copyright 2018 - 2024, MIT Lincoln Laboratory
# SPDX-License-Identifier: BSD-2-Clause

# Name of file containing queries
if [ -z "$1" ]; then
    printf "Name of file containing queries: "
    IFS= read -r INQUERIES
else
    INQUERIES=$1
fi

# Name of file containing groups for each query
# We assume that this file has the same name as $INQUERIES
# but we just a _group suffix
# https://stackoverflow.com/a/22957485/363829
INGROUPS=$(echo "$INQUERIES" | sed "s/.txt/_groups.txt/")

# Name of output directory where we write the logs to
if [ -z "$2" ]; then
    printf "Name of output directory where we write the logs to: "
    IFS= read -r OUTDIR
else
    OUTDIR=$2
fi

# Remove trailing slash
# https://stackoverflow.com/a/32845647/363829
OUTDIR=$(echo $OUTDIR | sed 's:/*$::')

# OpenSky Network username
if [ -z "$3" ]; then
    printf "OpenSky Username: "
    IFS= read -r OSNUSER
else
    OSNUSER=$3
fi

# OpenSky Network password
if [ -z "$4" ]; then
    # Query user for OpenSky Network password
    # https://stackoverflow.com/a/2654048/363829
    # https://stackoverflow.com/a/3980713/363829
    stty_orig=$(stty -g) # save original terminal setting.
    stty -echo           # turn-off echoing.
    printf "OpenSky Network Password: "
    IFS= read -r PASSWORD
    stty "$stty_orig"    # restore terminal setting.
else
    PASSWORD=$4
fi

# Create counter
count=1

# https://unix.stackexchange.com/a/26604/1408
while true
do
    # Start timer
    SECONDS=0

    read -r f1 <&5 || break
    read -r f2 <&6 || break

    # Create full file path of output file
    OUTFILE=$OUTDIR/$f2/$count.txt

    # Parse query
    QUERY=$f1
    sleep 3
    # SSH into Impala shell, execute query, exit
    # https://stackoverflow.com/a/41173047/363829
    # Expect #1: Enter ${OSNUER}@data.opensky-network.org's password
    # Expect #2: If the password was denied, try again...Permission denied, please try again.
    # Expect #3: Execute query...[hadoop]
    expect <(cat <<EOD
    spawn script -f -c "ssh -p 2230 -l $OSNUSER data.opensky-network.org" $OUTFILE
    sleep 1
    expect "password:"
    sleep 1
    send -- "${PASSWORD}\r"
    sleep 1
    expect "hadoop"
    sleep 1
    send -- "${QUERY}\r"
    interact
EOD
    )

    # Advance counter
    count=$(( $count + 1 ))

    # Sleep to avoid slamming database
    # https://unix.stackexchange.com/a/354456/1408
    # https://stackoverflow.com/a/6348941/363829
    SLEEPTIME=$((5-$SECONDS))
    if (( $SLEEPTIME > 0 )) ; then
        echo Sleeping for $SLEEPTIME seconds
        sleep ${SLEEPTIME}s
    fi

done 5<$INQUERIES 6<$INGROUPS
