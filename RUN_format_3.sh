#!/bin/bash
# Copyright 2018 - 2024, MIT Lincoln Laboratory
# SPDX-License-Identifier: BSD-2-Clause

# RUN_format_3.sh
#
# $1 : Parent directory of .txt logs

# Parent directory of logs of OpenSky Impala shell in .txt format (see Step 2)
if [ -z "$1" ]; then
    printf "Name of Parent directory of logs of OpenSky Impala shell in .txt format:"
    IFS= read -r INDIR
else
    INDIR=$1
fi
echo "input directory = $INDIR"

# Find directory names
# https://askubuntu.com/a/444554/244714
find "$(cd $INDIR ; pwd)" -mindepth 1 -maxdepth 1 -type d> output/3_dirArchiveDepth1.txt
find "$(cd $INDIR ; pwd)" -mindepth 2 -maxdepth 2 -type d> output/3_dirArchiveDepth2.txt

# Create counter
count=1

# Find files in each directory
while read d; do
	find $d -name '*.txt' -print >> output/3_files.txt     

	#Advance counter
	count=$(( $count + 1 ))
done < output/3_dirArchiveDepth2.txt

# Timer and Counter
SECONDS=0
count=1

# Serial
while read d; do
	# Timer
	SECONDS=0
	
	# Call script to format from .txt to .csv
	bash formatLogs_3.sh $d

	# Record status to file and display to screen
	echo $SECONDS >> output/3_seconds.txt
	echo "i=$count, time=$SECONDS"
	
	# Advance counter
	count=$(( $count + 1 ))
done < output/3_files.txt	
