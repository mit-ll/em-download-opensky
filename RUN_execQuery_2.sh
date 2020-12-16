#!/bin/bash
# Copyright 2018 - 2020, MIT Lincoln Laboratory
# SPDX-License-Identifier: BSD-2-Clause

# This run script allows users to run execQuery_2.sh in serial but querying the user once for the OpenSky username and password 

# Query user for OpenSky Network username
printf "OpenSky Username: "
IFS= read -r OSNUSER

# Query user for OpenSky Network password
# https://stackoverflow.com/a/2654048/363829
# https://stackoverflow.com/a/3980713/363829
stty_orig=$(stty -g) # save original terminal setting.
stty -echo           # turn-off echoing.
printf "OpenSky Network Password: "
IFS= read -r PASSWORD
stty "$stty_orig"    # restore terminal setting.

#### After this line, list the execQuery_2 commands you want to run and use $OSNUSER and $PASSWORD as inputs
#### The next line is a notional example:
# ./execQuery_2.sh output/queries.txt output/2020-01-01/ $OSNUSER $PASSWORD
