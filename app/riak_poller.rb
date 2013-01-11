#!/usr/bin/env ruby

require 'rubygems'
require 'statsd'
require 'net/http'
require 'uri'
require 'json'

require '/opt/app/config.rb'

statsd = Statsd.new
riak_rpc_path = '/opt/app/riak_rpc_fetch'

stats = ['vnode_gets', 'vnode_puts', 'read_repairs', 'node_gets', 'node_puts', 'cpu_nprocs', 'sys_process_count', 'pbc_connects', 'pbc_active', 
  'node_get_fsm_time_mean', 'node_get_fsm_time_median', 'node_get_fsm_time_95', 'node_get_fsm_time_99', 'node_get_fsm_time_100', 
  'node_put_fsm_time_mean', 'node_put_fsm_time_median', 'node_put_fsm_time_95', 'node_put_fsm_time_99', 'node_put_fsm_time_100']

loop do
  $nodes.each do |node, config|
    prefix = "#{node}.riak"
    ip = config[:ip]

    # Test if node is up
    http = Net::HTTP.new(ip, 8098)
    http.open_timeout = 2

    uri = URI.parse("http://#{ip}:8098/ping")
    request = Net::HTTP::Get.new(uri.request_uri)

    begin
      ping = http.request(request)
    rescue Exception
      # skip the down nodes
      next
    end

    # Riak Stats
    stats_uri = URI.parse("http://#{ip}:8098/stats")

    begin
      status = JSON.parse(Net::HTTP.get_response(stats_uri).body)
    rescue Exception
      status = {}
    end

    stats.each do |stat|
      statsd.gauge("#{prefix}.#{stat}", status[stat].to_i)
    end

    # Transfers
    handoffs_command = "#{riak_rpc_path} riak@#{ip} riak_kv_status transfers | grep #{ip} | cut -f3 -d \"'\" | tr -cd [:alnum:]"

    handoffs = %x(#{handoffs_command}).to_s.strip 
    if(handoffs.empty?)
      handoffs = 0
    end
    statsd.gauge("#{prefix}.handoffs", handoffs)

    # Vnode Count
    vnode_command = "#{riak_rpc_path} riak@#{ip} riak_core_vnode_manager all_vnodes | grep -c kv_vnode"

    vnodes = %x(#{vnode_command}).to_s.strip 
    statsd.gauge("#{prefix}.primary_vnodes", vnodes)

    # Object Count
    object_uri = URI.parse("http://#{ip}:8098/buckets/bench/keys?keys=stream")

    begin
      object_count = Net::HTTP.get_response(object_uri).body.split(%r{"\d+"}).length - 1
    rescue Exception
      next
    end

    statsd.gauge("cluster.riak.object_count", object_count)
  end

  sleep 1
end
