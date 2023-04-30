#!/bin/bash

if [ $# -lt 1 ]; then
    echo "Usage: ./sim_ghdl.sh <entity name> [stop time (optional)]"
    echo "The entity itself should be under rtl/ directory, along with the testbench."
    echo "The testbench file MUST be named like so: <entity name>_tb.vhdl"
    exit 1
fi

stop_time=100us

if [ $# -eq 2 ]; then
    stop_time=$2
fi


entity_file=rtl/$1.vhdl
testbench_file=rtl/$1\_tb.vhdl

if [ ! -f $entity_file ]; then
    echo $entity_file "does not exist!"
    exit 2
fi 

if [ ! -f $testbench_file ]; then
    echo $testbench_file "does not exist!"
    exit 3
fi

testbench_entity=$1_tb
waveform_file=$1.ghw

# analyze
ghdl -a $entity_file
ghdl -a $testbench_file

# elaborate
ghdl -e $testbench_entity

# run the simulation and generate the waveform
./$testbench_entity --stop-time=$stop_time --wave=$waveform_file

# cleanup
rm *.o
rm $testbench_entity
rm *.cf
