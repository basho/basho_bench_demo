#!/bin/bash
#

test_type=$1

statsd_host="${STATSD_HOST:-127.0.0.1}"
statsd_port="${STATSD_PORT:-8125}"

basho_bench_path="/opt/basho_bench"

node_count=4

function cleanup
{
  # Close UDP socket
  exec 3<&-
  exec 3>&-

  # Kill background processes 
  for i in $(seq 1 $node_count); do
    kill -9 ${pids[$i]} 2>/dev/null
  done

  # Cleanup old test results
  rm -rf $basho_bench_path/results/*
}

# Clean up old data before we get started
cleanup

# Setup UDP socket with statsd server
exec 3<> /dev/udp/$statsd_host/$statsd_port

# Start Basho Bench test
for i in $(seq 1 $node_count); do
  HOME=/opt $basho_bench_path/basho_bench -d $basho_bench_path/results/riak_$i -n riak_$i $basho_bench_path/config/riak_$i.$test_type &
  pids[$i]=$!
done

sleep 5

while true; do
  cluster_read_count=0
  cluster_write_count=0
  cluster_read_latency=0
  cluster_write_latency=0
  cluster_error_count=0
  unset total_trans
  active_nodes=$node_count

  for i in $(seq 1 $node_count); do
    node_status=$(tail -1 $basho_bench_path/results/riak_$i/riak_$i/console.log | grep -c 'econnrefused\|shutdown')

    if [ $node_status -eq 0 ]; then
      node_read_status=$(tail -1 $basho_bench_path/results/riak_$i/riak_$i/get_latencies.csv 2>/dev/null | tr -d ',')
      node_write_status=$(tail -1 $basho_bench_path/results/riak_$i/riak_$i/put_latencies.csv 2>/dev/null | tr -d ',')
      
      node_read_count=$(echo $node_read_status | awk '{print $3}')
      node_write_count=$(echo $node_write_status | awk '{print $3}')
      node_read_latency=$(echo $node_read_status | awk '{print $6}')
      node_write_latency=$(echo $node_write_status | awk '{print $6}')

      total_trans[$i]=$(cat $basho_bench_path/results/riak_$i/riak_$i/summary.csv | tr -d ',' | awk '{print $3}' | paste -sd+ | bc)
    else
      node_read_count=0
      node_write_count=0
      node_read_latency=0
      node_write_latency=0
      active_nodes=$((active_nodes - 1))
    fi

    if [[ $node_read_count -eq "" ]]; then
      node_read_count=0
    fi
    if [[ $node_write_count -eq "" ]]; then
      node_write_count=0
    fi
    if [[ $node_read_latency -eq "" ]]; then
      node_read_latency=0
    fi
    if [[ $node_write_latency -eq "" ]]; then
      node_write_latency=0
    fi

    cluster_read_count=$((cluster_read_count + $node_read_count))
    cluster_write_count=$((cluster_write_count + $node_write_count))
    cluster_read_latency=$((cluster_read_latency + $node_read_latency)) 
    cluster_write_latency=$((cluster_write_latency + $node_write_latency))

    # Send data
    printf "riak_${i}_read_throughput:$node_read_count|g" >&3
    printf "riak_${i}_write_throughput:$node_write_count|g" >&3
    printf "riak_${i}_read_latency:$((node_read_latency/1000))|g" >&3
    printf "riak_${i}_write_latency:$((node_write_latency/1000))|g" >&3

    echo "riak_${i}_read_throughput:$node_read_count|g"
    echo "riak_${i}_write_throughput:$node_write_count|g"
    echo "riak_${i}_read_latency:$((node_read_latency/1000))|g"
    echo "riak_${i}_write_latency:$((node_write_latency/1000))|g" 
  done # END node for loop

  cluster_error_count=$(cat $basho_bench_path/results/riak_*/riak_*/errors.csv | cut -f4 -d '"' | paste -sd+ | bc)

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
