#!/bin/bash

. /etc/basho-bench-demo/nodes

RIAK_HOME=riak
RIAK_BIN=$RIAK_HOME/bin
SSH_CMD="ssh -t"

function execute_command {

  for HOST in $NODES;
  do
    $SSH_CMD riak@$HOST $1
  done

}

execute_command "$RIAK_BIN/riak stop"
sleep 5
execute_command "rm -rf $RIAK_HOME/data/bitcask/*"
execute_command "$RIAK_BIN/riak_start"

