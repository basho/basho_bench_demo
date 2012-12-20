#!/bin/bash

source /opt/app/config.txt

function create_bench_config {
  node=$1
  start_op=$2
  failed_node=$3

  if [ -n "$failed_node" ]; then
    my_node="${node}_${failed_node}"
    start_op=$(cat $basho_bench_path/config/$failed_node.verify | grep key_generator | cut -f 4 -d',' | tr -d '[:space:]')
    state_dir="\/opt\/basho_bench\/state\/${failed_node}"
  else
    my_node=$node
    state_dir="\/opt\/basho_bench\/state\/${my_node}"
  fi

  # Create write and verify phase configs for each node
  cp $basho_bench_path/config/riakc_pb.template $basho_bench_path/config/$my_node.write
  cp $basho_bench_path/config/riakc_pb.template $basho_bench_path/config/$my_node.verify
  cp $basho_bench_path/config/riakc_pb.template $basho_bench_path/config/$my_node.delete

  # Set node IP in configs
  node_ip=$(echo ${nodes[$node]} | tr -s '.' ',')
  sed -i "s/%IP%/$node_ip/g" $basho_bench_path/config/$my_node.*

  # Set the number of operations to perform
  sed -i "s/%START_OP%/$start_op/g" $basho_bench_path/config/$my_node.* 
  sed -i "s/%OPERATIONS%/$num_operations/g" $basho_bench_path/config/$my_node.* 

  sed -i "s/%STATE_DIR%/${state_dir}_write/g" $basho_bench_path/config/$my_node.write
  sed -i "s/%STATE_DIR%/${state_dir}_verify/g" $basho_bench_path/config/$my_node.verify
  sed -i "s/%STATE_DIR%/${state_dir}_delete/g" $basho_bench_path/config/$my_node.delete

  # Set the operation type
  sed -i "s/%OPERATION%/put/g" $basho_bench_path/config/$my_node.write 
  sed -i "s/%OPERATION%/get/g" $basho_bench_path/config/$my_node.verify 
  sed -i "s/%OPERATION%/delete/g" $basho_bench_path/config/$my_node.delete
}

