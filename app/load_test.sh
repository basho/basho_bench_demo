#!/usr/bin/env bash

source /opt/app/config.txt
source /opt/app/functions.sh

TEST_TYPE=$1
ACTIVE_NODES=${#NODES[@]}
declare -A NODE_STATUS

function start_worker {
  WORKER=$1
  HOME=/opt $BASHO_BENCH_PATH/basho_bench -d $BASHO_BENCH_PATH/results/$WORKER $BASHO_BENCH_PATH/config/$WORKER.$TEST_TYPE 2>&1 >/dev/null &
}

# Start Basho Bench test
for NODE in ${!NODES[@]}; do
  start_worker $NODE
done

sleep 3

while [[ $ACTIVE_NODES -gt 0 ]]; do
  # Reset vars for next log read cycle
  ACTIVE_NODES=${#NODES[@]}

  # Evaluates the Basho Bench logs for each node
  for NODE in ${!NODES[@]}; do
    # Skip this node if it is complete or failed
    if [[ ${NODE_STATUS["${NODE}_complete"]} -gt 0 ]] || [[ ${NODE_STATUS["${NODE}_fail"]} -gt 0 ]]; then
      ACTIVE_NODES=$((ACTIVE_NODES - 1))
      continue
    fi

    # If the previous node was in a failed state, spwan new Basho Bench instance with the current node
    if [[ ${NODE_STATUS["${PREVIOUS_NODE}_fail"]} -gt 0 ]]; then
      # Create new basho bench config
      create_bench_config $NODE 0 $PREVIOUS_NODE   

      # Start basho bench process
      NEW_WORKER="${NODE}_${PREVIOUS_NODE}"
      start_worker $NEW_WORKER
      rm -f ${BASHO_BENCH_PATH}/results/${PREVIOUS_NODE}/current
    fi

    # Update node status
    NODE_STATUS["${NODE}_complete"]=$(tail -qn 1 $BASHO_BENCH_PATH/results/${NODE}/current/console.log 2>/dev/null | grep -c 'shutdown\|stopped')
    NODE_STATUS["${NODE}_fail"]=$(tail -qn 1 $BASHO_BENCH_PATH/results/${NODE}/current/console.log 2>/dev/null | grep -c 'econnrefused')

    PREVIOUS_NODE=$NODE
  done # END for loop

  sleep 1
done # END while loop
