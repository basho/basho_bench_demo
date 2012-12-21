#!/bin/bash

set -e

source /opt/app/config.txt

RIAK_RPC_FETCH_PATH="/opt/app/riak_rpc_fetch"

VARIABLES=("vnode_gets" "vnode_puts" "read_repairs" "node_gets" "node_puts" "cpu_nprocs" "sys_process_count" "pbc_connects" "pbc_active" \
  "node_get_fsm_time_mean" "node_get_fsm_time_median" "node_get_fsm_time_95" "node_get_fsm_time_99" "node_get_fsm_time_100" \
  "node_put_fsm_time_mean" "node_put_fsm_time_median" "node_put_fsm_time_95" "node_put_fsm_time_99" "node_put_fsm_time_100")

function close_socket 
{ 
  # Close StatsD socket
  exec 4<&-
  exec 4>&-
}

# Open socket to StatsD
exec 4<> /dev/udp/$STATSD_HOST/$STATSD_PORT

while true; do
  for NODE in ${!NODES[@]}; do
    PREFIX="${NODE}.riak"

    #
    # Riak Status
    #
    STATUS=$($RIAK_RPC_FETCH_PATH riak@${NODES[$NODE]} riak_kv_stat get_stats | tr -s ',' ':' | tr -d '[{ }]')
 
    for STAT in ${VARIABLES[@]}; do
      RE_PREFIX=$'(\n|^)'
      RE_SUFFIX=$':([^\n]*)'
 
      RE="$RE_PREFIX$STAT$RE_SUFFIX"
 
      if [[ "$STATUS" =~ $RE ]]; then
        VALUE=${BASH_REMATCH[2]%?}
        printf "$PREFIX.$STAT:$VALUE|g" >&4
      fi
    done # END FOR

    #
    # Transfers
    #
    HANDOFFS=$($RIAK_RPC_FETCH_PATH riak@${NODES[$NODE]} riak_kv_status transfers | grep ${NODES[$NODE]} | cut -f3 -d "'" | tr -cd [:alnum:])
    HANDOFFS=${HANDOFFS:-0}
    printf "$PREFIX.handoffs:$HANDOFFS|g" >&4

    #
    # Vnode Count
    #
    PRIMARY_VNODES=$($RIAK_RPC_FETCH_PATH riak@${NODES[$NODE]} riak_core_vnode_manager all_vnodes | grep kv_vnode | wc -l)
    printf "$PREFIX.primary_vnodes:$PRIMARY_VNODES|g" >&4

    sleep 1
  done # END FOR
done # END WHILE

trap close_socket EXIT
