#!/bin/bash
# Copyright 2018 - 2020, MIT Lincoln Laboratory
# SPDX-License-Identifier: BSD-2-Clause
#
# $1 : Name of file of an OpenSk Network logged query to be parsed
#
# This script can be called directly or by a run script

# File to be parsed
INFILE=$1

# File to create
if [ -z "$2" ]; then
    # Create output filename based on INFILE
    OUTFILE=$(echo "$INFILE" | sed "s/.txt/.csv/")
else
    OUTFILE=$2
fi

# Transform log into csv
# https://opensky-network.org/data/impala
cat $INFILE | grep "^|.*" | sed -e 's/\s*|\s*/,/g' -e 's/^,\|,$//g' -e 's/NULL//g' | awk '!seen[$0]++' >> $OUTFILE

# Remove extra headers
# https://www.unix.com/shell-programming-and-scripting/162097-sed-pattern-delete-lines-containing-pattern-except-first-occurance.html
sed -i '2,${/time/d;}' $OUTFILE
