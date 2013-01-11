#!/usr/bin/env ruby

require 'rubygems'
require 'net/http'
require 'uri'

require '/opt/app/config.rb'

$test_type = ARGV[0]

if not ['read', 'write', 'delete'].include?($test_type)
  puts 'invalid argument'
  exit 1
end 

active_nodes = $nodes.length

def start_worker(worker)
  job = fork do
    exec "HOME=/opt #{$basho_bench_path}/basho_bench -d #{$basho_bench_path}/results/#{worker} #{$basho_bench_path}/config/#{worker}.#{$test_type} 2>&1 >/dev/null &"
  end
  Process.detach(job)
end

# Start Basho Bench test
$nodes.each do |node, config|
  start_worker(node)

  $nodes[node][:fail]     = 0
  $nodes[node][:complete] = 0
end

# Wait for Basho Bench to spin up
sleep 3

previous_node = $nodes.keys.last

while active_nodes > 0 
  # Reset vars for next log read cycle
  active_nodes = $nodes.length

  # Evaluates the Basho Bench logs for each node
  $nodes.each do |node, config|
    # Skip this node if it is complete or failed
    if $nodes[node][:complete] > 0 || $nodes[node][:fail] > 0
      active_nodes -= 1
      next
    end

    # If the previous node was in a failed state, spwan new Basho Bench instance with the current node
    if $nodes[previous_node][:fail] > 0
      # Create new basho bench config
      %x(/opt/app/create_bench_config.rb #{node} 0 #{previous_node})   

      # Start basho bench process
      new_worker = "#{node}_#{previous_node}"
      start_worker(new_worker)

      %x(rm -f #{$basho_bench_path}/results/#{previous_node}/current)
    end

    # Test if node is up
    http = Net::HTTP.new($nodes[node][:ip], 8098)
    http.open_timeout = 2

    uri = URI.parse("http://#{$nodes[node][:ip]}:8098/ping")
    request = Net::HTTP::Get.new(uri.request_uri)

    begin
      ping = http.request(request)
    rescue Exception
      $nodes[node][:fail] = 1
    end

    # Update node status
    $nodes[node][:complete] = %x(cat #{$basho_bench_path}/results/#{node}/current/console.log 2>/dev/null | grep -c 'shutdown\\|stopped').to_i

    previous_node = node
  end 

  sleep 1
end
