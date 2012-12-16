#!/bin/bash

source /opt/app/config.txt

# Create basho bench configs for each node
for node in ${!nodes[@]}; do
  # Create write and verify phase configs for each node
  cp $basho_bench_path/config/riakc_pb.template $basho_bench_path/config/$node.write
  cp $basho_bench_path/config/riakc_pb.template $basho_bench_path/config/$node.verify

  # Set node IP in configs
  node_ip=$(echo ${nodes[$node]} | tr -s '.' ',')
  sed -i "s/%IP%/$node_ip/g" $basho_bench_path/config/$node.*

  # Set the number of operations to perform
  sed -i "s/%OPERATIONS%/$num_operations/g" $basho_bench_path/config/$node.* 

  # Set the operation type
  sed -i "s/%OPERATION%/put/g" $basho_bench_path/config/$node.write 
  sed -i "s/%OPERATION%/get/g" $basho_bench_path/config/$node.verify 
done

row=1
column=1

for node in ${!nodes[@]}; do
  json="$json \"$node\":{source: statsSourceUrl(\"${node}_*\", {\"from\": \"-2minutes\"}), refresh_interval: 2000, TimeSeries:{parent: \"#g${row}-${column}\", title: \"${node}\"}},"

  column=$((column + 1))
  if [ $column -eq 4 ]; then
    row=$((row + 1))
    column=1
  fi
done

cp /opt/demo/js/index.js.template /opt/demo/js/index.js
sed -i "s/%NODE_CONFIG%/$json/g" /opt/demo/js/index.js

