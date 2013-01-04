#!/bin/bash

source /opt/app/config.txt
source /opt/app/functions.sh

START_OP=0

# Create basho bench configs for each node
for NODE in ${!NODES[@]}; do
  create_bench_config $NODE $START_OP
  START_OP=$((START_OP + $NUM_OPERATIONS))
done

for NODE in ${!NODES[@]}; do
  NODE_CONFIG="${NODE_CONFIG}\naddGraph('${NODE}', '${NODE}.test.*_throughput');"
done

cp /opt/demo/js/index.js.template /opt/demo/js/index.js
sed -i "s/%NODE_CONFIG%/$NODE_CONFIG/g" /opt/demo/js/index.js

