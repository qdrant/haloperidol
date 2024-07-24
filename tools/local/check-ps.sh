#!/bin/bash

# Get the average CPU usage over all CPUs
CPU_USAGE=$(mpstat 1 1 | awk '/Average/ {print 100 - $NF}')

# Get the memory usage in percentage
MEM_USAGE=$(free | awk '/Mem/ {printf("%.2f"), $3/$2 * 100.0}')

# Check if CPU usage or memory usage is higher than 80%
if (( $(echo "$CPU_USAGE > 80" | bc -l) )) || (( $(echo "$MEM_USAGE > 80" | bc -l) )); then
    # Get the top 10 processes by CPU usage
    ENTRY_TS=$(date +%Y-%m-%dT%H:%M:%S%z) 
    ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%cpu | head -n 11 | tail -n 10 | while read -r line; do
        # Extract fields
        PROC_PID=$(echo $line | awk '{print $1}')
        PROC_PPID=$(echo $line | awk '{print $2}')
        PROC_CMD=$(echo $line | awk '{print $3}')
        PROC_MEM=$(echo $line | awk '{print $4}')
        PROC_CPU=$(echo $line | awk '{print $5}')
        
        # Log in logfmt style with timestamp
        echo "timestamp=$ENTRY_TS pid=$PROC_PID ppid=$PROC_PPID cmd=\"$PROC_CMD\" mem=$PROC_MEM cpu=$PROC_CPU" >> /var/log/check-ps.log
    done
fi
