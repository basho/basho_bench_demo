#!/usr/bin/env ruby

require 'rubygems'
require 'statsd'

statsd = Statsd.new

nodes = {'node_1' => '10.34.94.11', 'node_2' => '10.78.194.106', 'node_3' => '10.204.214.109', 'node_4' => '10.40.107.127'}
basho_bench_path = '/opt/basho_bench/results'
num_operations = 10000

loop do
  total_trans = 0

  # Evaluates the Basho Bench logs for each node
  nodes.each do |node, ip|
    prefix = "#{node}.test"

    node_stopped = 1
    node_failover_stopped = 1

    if(File::exists?("#{basho_bench_path}/#{node}/current/console.log"))
      node_stopped = %x(tail -qn 1 #{basho_bench_path}/#{node}/current/console.log 2>/dev/null | grep -c 'shutdown\\|stopped\\|econnrefused').to_i
    end
    if(!Dir.glob("#{basho_bench_path}/#{node}_*/current").empty?)
      node_failover_stopped = %x(tail -qn 1 #{basho_bench_path}/#{node}_*/current/console.log 2>/dev/null | grep -c 'shutdown\\|stopped\\|econnrefused').to_i
    end

    if(node_stopped == 0 || node_failover_stopped == 0)
      node_read_status   = %x(tail -qn 1 #{basho_bench_path}/#{node}*/current/get_latencies.csv 2>/dev/null | tr -d ',')
      node_write_status  = %x(tail -qn 1 #{basho_bench_path}/#{node}*/current/put_latencies.csv 2>/dev/null | tr -d ',')
      node_delete_status = %x(tail -qn 1 #{basho_bench_path}/#{node}*/current/delete_latencies.csv 2>/dev/null | tr -d ',')
      
      node_read_count     = %x(echo "#{node_read_status}" | awk '{print $3 + $11}' | paste -sd+ | bc).to_i
      node_write_count    = %x(echo "#{node_write_status}" | awk '{print $3 + $11}' | paste -sd+ | bc).to_i
      node_delete_count   = %x(echo "#{node_delete_status}" | awk '{print $3 + $11}' | paste -sd+ | bc).to_i
      node_read_latency   = %x(echo "#{node_read_status}" | awk '{print $6}').to_i
      node_write_latency  = %x(echo "#{node_write_status}" | awk '{print $6}').to_i
      node_delete_latency = %x(echo "#{node_delete_status}" | awk '{print $6}').to_i

      node_error_count    = %x(cat #{basho_bench_path}/#{node}*/current/errors.csv 2>/dev/null| cut -f2 -d ',' | grep '[[:digit:]]' | paste -sd+ | bc).to_i
    else
      # Set all values for inactive nodes to 0
      node_read_count     = 0
      node_write_count    = 0
      node_delete_count   = 0
      node_read_latency   = 0
      node_write_latency  = 0
      node_delete_latency = 0
      node_error_count    = 0
    end

    # Send data
    statsd.gauge("#{prefix}.read_throughput", node_read_count)
    statsd.gauge("#{prefix}.write_throughput", node_write_count)
    statsd.gauge("#{prefix}.delete_throughput", node_delete_count)
    statsd.gauge("#{prefix}.read_latency", node_read_latency/1000)
    statsd.gauge("#{prefix}.write_latency", node_write_latency/1000)
    statsd.gauge("#{prefix}.delete_latency", node_delete_latency/1000)
    statsd.gauge("#{prefix}.error_count", node_error_count)
  end # END for loop

  # Record the overall completion percentage
  total_trans = %x(cat #{basho_bench_path}/*/current/summary.csv 2>/dev/null | tr -d ',' | awk '{print $3}' | paste -sd+ | bc).to_i

  complete_percent = (total_trans*100/num_operations/nodes.length).ceil

  # Fudge factor for Basho Bench lossy logging
  if(complete_percent == 99)
    complete_percent = 100
  end

  statsd.gauge("cluster.test.total_transactions", total_trans)
  statsd.gauge("cluster.test.completion", complete_percent)

  sleep 1
end # END loop
