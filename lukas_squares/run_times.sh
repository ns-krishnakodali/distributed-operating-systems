#!/bin/bash

declare -a exec_times

for i in {1..10}
do
    result=$(time gleam run)
    exec_time=$(echo "$result" | grep -o "Execution Time: [0-9.]*" | awk '{print $3}')
    exec_times+=($exec_time)
done

total_time=0
for time in "${exec_times[@]}"
do
    total_time=$(echo "$total_time + $time" | bc)
done

average_time=$(echo "scale=6; $total_time / 10" | bc)
echo "Average execution time: $average_time"
