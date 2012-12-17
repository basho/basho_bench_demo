#!/bin/bash

source /opt/app/config.txt

statsd_host="${STATSD_HOST:-127.0.0.1}"
statsd_port="${STATSD_PORT:-8125}"

ps aux | grep 'basho_bench\|load_test.sh' | grep -v grep | awk '{print $2}' | xargs -I % kill -9 %

exec 3<> /dev/udp/$statsd_host/$statsd_port

for node in ${!nodes[@]}; do
  printf "${node}_read_throughput:0|g" >&3
  printf "${node}_write_throughput:0|g" >&3
  printf "${node}_read_latency:0|g" >&3
  printf "${node}_write_latency:0|g" >&3
  printf "error_${node}:0|g" >&3
done

printf "cluster_read_throughput:0|g" >&3
printf "cluster_write_throughput:0|g" >&3
printf "cluster_read_latency:0|g" >&3
printf "cluster_write_latency:0|g" >&3
printf "cluster_error_count:0|g" >&3
printf "test_completion:0|g" >&3

# Close UDP socket
exec 3<&-
exec 3>&-

