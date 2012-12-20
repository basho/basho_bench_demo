#!/bin/bash

source /opt/app/config.txt
source /opt/app/functions.sh

start_op=0

# Create basho bench configs for each node
for node in ${!nodes[@]}; do
  create_bench_config $node $start_op
  start_op=$((start_op + $num_operations))
done

row=1
column=1

for node in ${!nodes[@]}; do
  json="$json \"$node\":{source: statsSourceUrl(\"${node}_*_throughput\", {\"from\": \"-2minutes\"}), refresh_interval: 2000, TimeSeries:{parent: \"#g${row}-${column}\", title: \"${node}\"}},"

  column=$((column + 1))
  if [ $column -eq 4 ]; then
    row=$((row + 1))
    column=1
  fi
done

cp /opt/demo/js/index.js.template /opt/demo/js/index.js
sed -i "s/%NODE_CONFIG%/$json/g" /opt/demo/js/index.js

