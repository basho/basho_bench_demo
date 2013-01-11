#!/usr/bin/env ruby

require 'rubygems'
require 'fileutils'
require 'statsd'

require '/opt/app/config.rb'

statsd = Statsd.new

# Kill basho bench processes
%x(pgrep -f 'basho_bench|load_test.rb' | xargs -I % kill -9 %)

# Remove old state directories
FileUtils.rm_r Dir.glob("#{$basho_bench_path}/state/*"), :force => true
FileUtils.rm_f Dir.glob("#{$basho_bench_path}/results/*/current")

# Reset test stats
$nodes.each do |node, config|
  statsd.gauge("#{node}.test.read_throughput", 0)
  statsd.gauge("#{node}.test.write_throughput", 0)
  statsd.gauge("#{node}.test.delete_throughput", 0)
  statsd.gauge("#{node}.test.read_latency", 0)
  statsd.gauge("#{node}.test.write_latency", 0)
  statsd.gauge("#{node}.test.delete_latency", 0)
  statsd.gauge("#{node}.test.error_count", 0)
end

statsd.gauge("cluster.test.total_transactions", 0)
statsd.gauge("cluster.test.completion", 0)

