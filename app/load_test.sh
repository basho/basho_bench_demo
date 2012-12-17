#!/bin/bash

source /opt/app/config.txt

test_type=$1

statsd_host="${STATSD_HOST:-127.0.0.1}"
statsd_port="${STATSD_PORT:-8125}"

function cleanup
{
  # Close UDP socket
  exec 3<&-
  exec 3>&-

  # Kill background processes 
  for node in ${!nodes[@]}; do
    kill -9 ${pids[$node]} 2>/dev/null
  done
}

# Clean up old data before we get started
cleanup

# Setup UDP socket with statsd server
exec 3<> /dev/udp/$statsd_host/$statsd_port

# Start Basho Bench test
for node in ${!nodes[@]}; do
  HOME=/opt $basho_bench_path/basho_bench -d $basho_bench_path/results/$node $basho_bench_path/config/$node.$test_type &
  pids[$node]=$!
  echo ${pids[$node]}
done

sleep 5

while true; do
  # Reset vars for next log read cycle
  cluster_read_count=0
  cluster_write_count=0
  cluster_read_latency=0
  cluster_write_latency=0
  cluster_error_count=0
  unset total_trans
  active_nodes=$node_count
  i=0

  # Evaluates the Basho Bench logs for each node
  for node in ${!nodes[@]}; do
    node_complete=$(tail -1 $basho_bench_path/results/$node/current/console.log 2>/dev/null | grep -c 'shutdown')
    node_error=$(tail -1 $basho_bench_path/results/$node/current/console.log 2>/dev/null | grep -c 'econnrefused')

    if [ $node_complete -eq 0 -a $node_error -eq 0 ]; then
      node_read_status=$(tail -1 $basho_bench_path/results/$node/current/get_latencies.csv 2>/dev/null | tr -d ',')
      node_write_status=$(tail -1 $basho_bench_path/results/$node/current/put_latencies.csv 2>/dev/null | tr -d ',')
      
      node_read_count=$(echo $node_read_status | awk '{print $3}')
      node_write_count=$(echo $node_write_status | awk '{print $3}')
      node_read_latency=$(echo $node_read_status | awk '{print $6}')
      node_write_latency=$(echo $node_write_status | awk '{print $6}')

      total_trans[$i]=$(cat $basho_bench_path/results/$node/current/summary.csv 2>/dev/null | tr -d ',' | awk '{print $3}' | paste -sd+ | bc)
      i=$((i + 1))
    else
      # Set all values for inactive nodes to 0
      node_read_count=0
      node_write_count=0
      node_read_latency=0
      node_write_latency=0
      active_nodes=$((active_nodes - 1))
    fi

    # Set values to 0 if variable is null
    node_read_count=${node_read_count:-0}
    node_write_count=${node_write_count:-0}
    node_read_latency=${node_read_latency:-0}
    node_write_latency=${node_write_latency:-0}

    cluster_read_count=$((cluster_read_count + $node_read_count))
    cluster_write_count=$((cluster_write_count + $node_write_count))
    cluster_read_latency=$((cluster_read_latency + $node_read_latency)) 
    cluster_write_latency=$((cluster_write_latency + $node_write_latency))

    # Send data
    printf "${node}_read_throughput:$node_read_count|g" >&3
    printf "${node}_write_throughput:$node_write_count|g" >&3
    printf "${node}_read_latency:$((node_read_latency/1000))|g" >&3
    printf "${node}_write_latency:$((node_write_latency/1000))|g" >&3

    if [ $node_error -eq 1 ]; then
      printf "error_${node}:1|g" >&3
    fi

    echo "${node}_read_throughput:$node_read_count|g"
    echo "${node}_write_throughput:$node_write_count|g"
    echo "${node}_read_latency:$((node_read_latency/1000))|g"
    echo "${node}_write_latency:$((node_write_latency/1000))|g" 
  done # END node for loop

  cluster_error_count=$(cat $basho_bench_path/results/*/current/errors.csv 2>/dev/null| cut -f4 -d '"' | paste -sd+ | bc)

  if [ $active_nodes -gt 0 ]; then
    cluster_read_latency=$((cluster_read_latency / $active_nodes / 1000))
    cluster_write_latency=$((cluster_write_latency / $active_nodes / 1000))
    readarray -t sorted_trans < <(for a in "${total_trans[@]}"; do echo "$a"; done | sort)
    complete_percent=$(echo "scale=2;${sorted_trans[0]}/10000*100" | bc)
  else
    cluster_read_latency=0
    cluster_write_latency=0
    complete_percent=100
  fi

  printf "cluster_read_throughput:$cluster_read_count|g" >&3
  printf "cluster_write_throughput:$cluster_write_count|g" >&3
  printf "cluster_read_latency:$cluster_read_latency|g" >&3
  printf "cluster_write_latency:$cluster_write_latency|g" >&3
  printf "cluster_error_count:$cluster_error_count|g" >&3
  printf "test_completion:$complete_percent|g" >&3

  echo "cluster_error_count:$cluster_error_count|g"

  if [[ $active_nodes -eq 0 ]]; then
    # Close UDP socket
    cleanup
    exit 0
  fi

  sleep 1
done

trap cleanup EXIT
