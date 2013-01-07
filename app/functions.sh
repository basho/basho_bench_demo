#!/bin/bash

function create_bench_config {
  NODE=$1
  START_OP=$2
  FAILED_NODE=$3

  if [ -n "$FAILED_NODE" ]; then
    MY_NODE="${NODE}_${FAILED_NODE}"
    START_OP=$(cat $BASHO_BENCH_PATH/config/$FAILED_NODE.read | grep key_generator | cut -f 4 -d',' | tr -d '[:space:]')
  else
    MY_NODE=$NODE
  fi

  # Create write, read, and delete phase configs for each node
  cp $BASHO_BENCH_PATH/config/riakc_pb.template $BASHO_BENCH_PATH/config/$MY_NODE.write
  cp $BASHO_BENCH_PATH/config/riakc_pb.template $BASHO_BENCH_PATH/config/$MY_NODE.read
  cp $BASHO_BENCH_PATH/config/riakc_pb.template $BASHO_BENCH_PATH/config/$MY_NODE.delete

  # Set node IP in configs
  NODE_IP=$(echo ${NODES[$NODE]} | tr -s '.' ',')
  sed -i "s/%IP%/$NODE_IP/g" $BASHO_BENCH_PATH/config/$MY_NODE.*

  # Set the number of operations to perform
  sed -i "s/%START_OP%/$START_OP/g" $BASHO_BENCH_PATH/config/$MY_NODE.* 
  sed -i "s/%OPERATIONS%/$NUM_OPERATIONS/g" $BASHO_BENCH_PATH/config/$MY_NODE.* 

  # Set the operation type
  sed -i "s/%OPERATION%/put/g" $BASHO_BENCH_PATH/config/$MY_NODE.write 
  sed -i "s/%OPERATION%/get/g" $BASHO_BENCH_PATH/config/$MY_NODE.read 
  sed -i "s/%OPERATION%/delete/g" $BASHO_BENCH_PATH/config/$MY_NODE.delete
}

