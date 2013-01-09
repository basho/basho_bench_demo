#!/usr/bin/env ruby

require 'rubygems'
require 'statsd'

require '/opt/app/config.rb'

statsd = Statsd.new

basho_bench_results = $basho_bench_path + '/results'

loop do
  total_trans = 0

  # Evaluates the Basho Bench logs for each node
  $nodes.each do |node, config|
    prefix = "#{node}.test"

    node_stopped = -1
    node_failover_stopped = -1

    if(File::exists?("#{basho_bench_results}/#{node}/current/console.log"))
      node_stopped = %x(tail -qn 1 #{basho_bench_results}/#{node}/current/console.log 2>/dev/null | grep -c 'shutdown\\|stopped\\|econnrefused').to_i
    end

    if(!Dir.glob("#{basho_bench_results}/#{node}_*/current").empty?)
      node_failover_stopped = %x(tail -qn 1 #{basho_bench_results}/#{node}_*/current/console.log 2>/dev/null | grep -c 'shutdown\\|stopped\\|econnrefused').to_i
    end

    if(node_stopped == 0 || node_failover_stopped == 0)
      node_read_status   = %x(tail -qn 1 #{basho_bench_results}/#{node}*/current/get_latencies.csv 2>/dev/null | tr -d ',')
      node_write_status  = %x(tail -qn 1 #{basho_bench_results}/#{node}*/current/put_latencies.csv 2>/dev/null | tr -d ',')
      node_delete_status = %x(tail -qn 1 #{basho_bench_results}/#{node}*/current/delete_latencies.csv 2>/dev/null | tr -d ',')
      
      node_read_count     = %x(echo "#{node_read_status}" | awk '{print $3 + $11}' | paste -sd+ | bc).to_i
      node_write_count    = %x(echo "#{node_write_status}" | awk '{print $3 + $11}' | paste -sd+ | bc).to_i
      node_delete_count   = %x(echo "#{node_delete_status}" | awk '{print $3 + $11}' | paste -sd+ | bc).to_i
      node_read_latency   = %x(echo "#{node_read_status}" | awk '{print $6}').to_i
      node_write_latency  = %x(echo "#{node_write_status}" | awk '{print $6}').to_i
      node_delete_latency = %x(echo "#{node_delete_status}" | awk '{print $6}').to_i

      node_error_count    = %x(cat #{basho_bench_results}/#{node}*/current/summary.csv 2>/dev/null| cut -f5 -d ',' | grep '[[:digit:]]' | paste -sd+ | bc).to_i
    else
      # Set all values for inactive nodes to 0
      node_read_count     = 0
      node_write_count    = 0
      node_delete_count   = 0
      node_read_latency   = 0
      node_write_latency  = 0
      node_delete_latency = 0
    end

    # Save data
    statsd.gauge("#{prefix}.read_throughput", node_read_count)
    statsd.gauge("#{prefix}.write_throughput", node_write_count)
    statsd.gauge("#{prefix}.delete_throughput", node_delete_count)
    statsd.gauge("#{prefix}.read_latency", node_read_latency/1000)
    statsd.gauge("#{prefix}.write_latency", node_write_latency/1000)
    statsd.gauge("#{prefix}.delete_latency", node_delete_latency/1000)

    if(node_error_count)
      statsd.gauge("#{prefix}.error_count", node_error_count)
      node_error_count = nil
    end
  end # END for loop

  # Record the overall completion percentage
  total_trans = %x(cat #{basho_bench_results}/*/current/summary.csv 2>/dev/null | tr -d ',' | awk '{print $3}' | paste -sd+ | bc).to_i

  complete_percent = (total_trans*100/$num_operations/$nodes.length).ceil

  # Fudge factor for Basho Bench lossy logging
  if(complete_percent == 99 || complete_percent > 100)
    complete_percent = 100
  end

  statsd.gauge("cluster.test.total_transactions", total_trans)
  statsd.gauge("cluster.test.completion", complete_percent)

  sleep 1
end # END loop
