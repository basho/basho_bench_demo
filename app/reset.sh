#!/bin/bash

source /opt/app/config.txt

ps aux | grep 'basho_bench\|load_test.sh' | grep -v grep | awk '{print $2}' | xargs -I % kill -9 %

# Remove old state directories
rm -rf $BASHO_BENCH_PATH/state/*
rm -rf $BASHO_BENCH_PATH/results/*/current

# Open UDP socket to Statsd
exec 3<> /dev/udp/$STATSD_HOST/$STATSD_PORT

for NODE in ${!NODES[@]}; do
  printf "${NODE}.test.read_throughput:0|g" >&3
  printf "${NODE}.test.write_throughput:0|g" >&3
  printf "${NODE}.test.delete_throughput:0|g" >&3
  printf "${NODE}.test.read_latency:0|g" >&3
  printf "${NODE}.test.write_latency:0|g" >&3
  printf "${NODE}.test.delete_latency:0|g" >&3
  printf "${NODE}.test.error_count:0|g" >&3
done

printf "cluster.test.total_transactions:0|g" >&3
printf "cluster.test.completion:0|g" >&3

# Close UDP socket to Statsd
exec 3<&-
exec 3>&-

