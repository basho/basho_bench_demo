#!/usr/bin/env ruby

require '/opt/app/config.rb'

start_op = 0
node_config = String.new

# Create basho bench configs for each node
$nodes.sort.each do |node, config|
  %x(/opt/app/create_bench_config.rb #{node} #{start_op})
  start_op += $num_operations
end

# Add the nodes to the javascript template
$nodes.sort.each do |node, config|
  node_config = node_config + "\n  addGraph('#{node}', '#{node}.test.*_throughput');"
end

text = File.read('/opt/demo/js/index.js.template')
replace = text.gsub(/%NODE_CONFIG%/, node_config)
File.open('/opt/demo/js/index.js', 'w') { |file| file.puts replace }

# Restart the pollers
%x(/opt/app/riak_poller_control.rb restart)
%x(/opt/app/bench_poller_control.rb restart)
