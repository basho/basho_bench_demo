#!/bin/bash

source /opt/app/config.txt
source /opt/app/functions.sh

test_type=$1

function cleanup
{
  # Close UDP socket
  exec 3<&-
  exec 3>&-

  # Kill background processes 
  for node in ${!nodes[@]}; do
    kill -9 ${pids[$node]} 2>/dev/null
  done
 
  # Remove the current symlinks from all results so we don't
  # end up with old data on the first run of the for loop
#  rm -f $basho_bench_path/results/*/current
  rm -rf $basho_bench_path/state/*
}

function start_worker {
  worker=$1
  HOME=/opt $basho_bench_path/basho_bench -d $basho_bench_path/results/$worker $basho_bench_path/config/$worker.$test_type 2>&1 >/dev/null &
  pids[$worker]=$!
}

# Clean up old data before we get started
cleanup

# Setup UDP socket with statsd server
exec 3<> /dev/udp/$statsd_host/$statsd_port

# Start Basho Bench test
for node in ${!nodes[@]}; do
  start_worker $node
done

sleep 3

node_fail=0

while true; do
  # Reset vars for next log read cycle
  unset total_trans
  active_nodes=${#nodes[@]}

  # Evaluates the Basho Bench logs for each node
  for node in ${!nodes[@]}; do
    # If the previous node was in a failed state, spwan new Basho Bench instance with the current node
    if [ $node_fail -gt 0 ]; then
      # Create new basho bench config
      create_bench_config $node 0 $previous   

      # Start basho bench process
      new_worker="${node}_${previous}"
      start_worker $new_worker
  
      # Add remove the failed node from the $nodes array
      unset nodes["$previous"]
    fi

    # Update node status
    node_complete=$(tail -qn 1 $basho_bench_path/results/${node}/current/console.log 2>/dev/null | grep -c 'shutdown\|stopped')
    node_fail=$(tail -qn 1 $basho_bench_path/results/${node}/current/console.log 2>/dev/null | grep -c 'econnrefused')

    if [ $node_complete -eq 0 -a $node_fail -eq 0 ]; then
      node_read_status=$(tail -qn 1 $basho_bench_path/results/${node}*/current/get_latencies.csv 2>/dev/null | tr -d ',')
      node_write_status=$(tail -qn 1 $basho_bench_path/results/${node}*/current/put_latencies.csv 2>/dev/null | tr -d ',')
      node_delete_status=$(tail -qn 1 $basho_bench_path/results/${node}*/current/delete_latencies.csv 2>/dev/null | tr -d ',')
      
      node_read_count=$(echo "$node_read_status" | awk '{print $3}' | paste -sd+ | bc)
      node_write_count=$(echo "$node_write_status" | awk '{print $3}' | paste -sd+ | bc)
      node_delete_count=$(echo "$node_delete_status" | awk '{print $3}' | paste -sd+ | bc)
      node_read_latency=$(echo $node_read_status | awk '{print $6}')
      node_write_latency=$(echo $node_write_status | awk '{print $6}')
      node_delete_latency=$(echo $node_delete_status | awk '{print $6}')

      node_error_count=$(cat $basho_bench_path/results/${node}*/current/*_latencies.csv 2>/dev/null| cut -f11 -d ',' | paste -sd+ | bc)
    else
      # Set all values for inactive nodes to 0
      node_read_count=0
      node_write_count=0
      node_delete_count=0
      node_read_latency=0
      node_write_latency=0
      node_delete_latency=0
      active_nodes=$((active_nodes - 1))
    fi

    # Set values to 0 if variable is null
    node_read_count=${node_read_count:-0}
    node_write_count=${node_write_count:-0}
    node_delete_count=${node_delete_count:-0}
    node_read_latency=${node_read_latency:-0}
    node_write_latency=${node_write_latency:-0}
    node_delete_latency=${node_delete_latency:-0}
    node_error_count=${node_error_count:-0}

    # Send data
    printf "${node}_read_throughput:$node_read_count|g" >&3
    printf "${node}_write_throughput:$node_write_count|g" >&3
    printf "${node}_delete_throughput:$node_delete_count|g" >&3
    printf "${node}_read_latency:$((node_read_latency/1000))|g" >&3
    printf "${node}_write_latency:$((node_write_latency/1000))|g" >&3
    printf "${node}_delete_latency:$((node_delete_latency/1000))|g" >&3
    printf "${node}_error_count:$node_error_count|g" >&3

    if [ $node_fail -gt 0 ]; then
      printf "error_${node}:1|g" >&3
    fi
  
    previous=$node
  done # END node for loop


  # Record the overall completion percentage
  if [[ $test_type == "write" ]]; then
    result_file="put_latencies.csv"
  elif [[ $test_type == "delete" ]]; then
    result_file="delete_latencies.csv"
  else
    result_file="get_latencies.csv"
  fi

  total_trans=$(cat $basho_bench_path/results/*/current/*_latencies.csv 2>/dev/null | tr -d ',' | awk '{print $3}' | paste -sd+ | bc)
  complete_percent=$(echo "scale=2;${total_trans}/$num_operations/$node_count*100" | bc)

  printf "total_transactions:$total_trans|g" >&3
  printf "test_completion:$complete_percent|g" >&3

  if [[ $active_nodes -eq 0 ]]; then
    # Set the completion counter to 100
    printf "test_completion:100|g" >&3

    # Close UDP socket
    cleanup
    exit 0
  fi

  sleep 1
done # END while loop

trap cleanup EXIT
