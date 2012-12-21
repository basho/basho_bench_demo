#!/bin/bash

source /opt/app/config.txt
source /opt/app/functions.sh

TEST_TYPE=$1
declare -A PIDS
declare -A NODE_STATUS

function cleanup
{
  # Close UDP socket
  exec 3<&-
  exec 3>&-

  # Kill background processes 
  for NODE in ${!NODES[@]}; do
    kill -9 ${PIDS[$NODE]} 2>/dev/null
  done
 
  # Remove the current symlinks from all results so we don't
  # end up with old data on the first run of the for loop
#  rm -f $BASHO_BENCH_PATH/results/*/current
  rm -rf $BASHO_BENCH_PATH/state/*
}

function start_worker 
{
  WORKER=$1

  HOME=/opt $BASHO_BENCH_PATH/basho_bench -d $BASHO_BENCH_PATH/results/$WORKER $BASHO_BENCH_PATH/config/$WORKER.$TEST_TYPE 2>&1 >/dev/null &
  PIDS[$WORKER]=$!
}

function save_stat 
{
  OWNER=$1
  STAT=$2
  VALUE=${3:-0}
  STAT_CATEGORY=${4:-test}
  DB_TYPE=${5:-g}

  printf "${OWNER}.${STAT_CATEGORY}.${STAT}:${VALUE}|${DB_TYPE}" >&3
}

# Clean up old data before we get started
cleanup

# Setup UDP socket with statsd server
exec 3<> /dev/udp/$STATSD_HOST/$STATSD_PORT

# Start Basho Bench test
for NODE in ${!NODES[@]}; do
  start_worker $NODE
done

sleep 3

while true; do
  # Reset vars for next log read cycle
  unset TOTAL_TRANS
  ACTIVE_NODES=${#NODES[@]}

  # Evaluates the Basho Bench logs for each node
  for NODE in ${!NODES[@]}; do
    # If the previous node was in a failed state, spwan new Basho Bench instance with the current node
    if [[ ${NODE_STATUS["${PREVIOUS_NODE}_fail"]} -gt 0 ]]; then
      # Create new basho bench config
      create_bench_config $NODE 0 $PREVIOUS_NODE   

      # Start basho bench process
      NEW_WORKER="${NODE}_${PREVIOUS_NODE}"
      start_worker $new_worker
  
      # Add remove the failed node from the $NODES array
      unset NODES["$PREVIOUS_NODE"]
    fi

    NODE_STATUS["${NODE}_complete"]=${NODE_STATUS["${NODE}_complete"]:-0}
    NODE_STATUS["${NODE}_fail"]=${NODE_STATUS["${NODE}_fail"]:-0}

    if [ ${NODE_STATUS["${NODE}_complete"]} -eq 0 -a ${NODE_STATUS["${NODE}_fail"]} -eq 0 ]; then
      NODE_READ_STATUS=$(tail -qn 1 $BASHO_BENCH_PATH/results/${NODE}*/current/get_latencies.csv 2>/dev/null | tr -d ',')
      NODE_WRITE_STATUS=$(tail -qn 1 $BASHO_BENCH_PATH/results/${NODE}*/current/put_latencies.csv 2>/dev/null | tr -d ',')
      NODE_DELETE_STATUS=$(tail -qn 1 $BASHO_BENCH_PATH/results/${NODE}*/current/delete_latencies.csv 2>/dev/null | tr -d ',')
      
      NODE_READ_COUNT=$(echo "$NODE_READ_STATUS" | awk '{print $3 + $11}' | paste -sd+ | bc)
      NODE_WRITE_COUNT=$(echo "$NODE_WRITE_STATUS" | awk '{print $3 + $11}' | paste -sd+ | bc)
      NODE_DELETE_COUNT=$(echo "$NODE_DELETE_STATUS" | awk '{print $3 + $11}' | paste -sd+ | bc)
      NODE_READ_LATENCY=$(echo $NODE_READ_STATUS | awk '{print $6}')
      NODE_WRITE_LATENCY=$(echo $NODE_WRITE_STATUS | awk '{print $6}')
      NODE_DELETE_LATENCY=$(echo $NODE_DELETE_STATUS | awk '{print $6}')

      NODE_ERROR_COUNT=$(cat $BASHO_BENCH_PATH/results/${NODE}*/current/*_latencies.csv 2>/dev/null| cut -f11 -d ',' | paste -sd+ | bc)
    else
      # Set all values for inactive nodes to 0
      NODE_READ_COUNT=0
      NODE_WRITE_COUNT=0
      NODE_DELETE_COUNT=0
      NODE_READ_LATENCY=0
      NODE_WRITE_LATENCY=0
      NODE_DELETE_LATENCY=0
      ACTIVE_NODES=$((ACTIVE_NODES - 1))
    fi

    # Update node status
    NODE_STATUS["${NODE}_complete"]=$(tail -qn 1 $BASHO_BENCH_PATH/results/${NODE}/current/console.log 2>/dev/null | grep -c 'shutdown\|stopped')
    NODE_STATUS["${NODE}_fail"]=$(tail -qn 1 $BASHO_BENCH_PATH/results/${NODE}/current/console.log 2>/dev/null | grep -c 'econnrefused')

    # Send data
    save_stat $NODE "read_throughput" $NODE_READ_COUNT
    save_stat $NODE "write_throughput" $NODE_WRITE_COUNT
    save_stat $NODE "delete_throughput" $NODE_DELETE_COUNT
    save_stat $NODE "read_latency" $((NODE_READ_LATENCY/1000))
    save_stat $NODE "write_latency" $((NODE_WRITE_LATENCY/1000))
    save_stat $NODE "delete_latency" $((NODE_DELETE_LATENCY/1000))
    save_stat $NODE "error_count" $NODE_ERROR_COUNT

    if [ ${NODE_STATUS["${NODE}_fail"]} -gt 0 ]; then
      save_stat $NODE "error" 1
    fi
  
    PREVIOUS_NODE=$NODE
  done # END for loop

  # Record the overall completion percentage
  TOTAL_TRANS=$(cat $BASHO_BENCH_PATH/results/*/current/*_latencies.csv 2>/dev/null | tr -d ',' | awk '{print $3 + $11}' | paste -sd+ | bc)
  COMPLETE_PERCENT=$(echo "scale=2;${TOTAL_TRANS}/${NUM_OPERATIONS}/${NODE_COUNT}*100" | bc)

  save_stat "cluster" "total_transactions" $TOTAL_TRANS
  save_stat "cluster" "completion" $COMPLETE_PERCENT

  # Get total object count from cluster
  OBJECT_COUNT=$(curl -s http://${NODES[$NODE]}:8098/buckets/bench/index/\$key/0/9999999999999999 | tr -cs [:digit:] "\n" | grep [[:digit:]] | wc -l)
  save_stat "cluster" "object_count" $OBJECT_COUNT "riak" 

  if [[ $ACTIVE_NODES -eq 0 ]]; then
    # Set the completion counter to 100
    save_stat "cluster" "completion" 100

    # Get total object count from cluster
    OBJECT_COUNT=$(curl -s http://${NODES[$NODE]}:8098/buckets/bench/index/\$key/0/9999999999999999 | tr -cs [:digit:] "\n" | grep [[:digit:]] | wc -l)
    save_stat "cluster" "object_count" $OBJECT_COUNT "riak"

    # Close UDP socket
    cleanup
    exit 0
  fi
done # END while loop

trap cleanup EXIT
