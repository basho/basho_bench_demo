#!/usr/bin/env ruby

require '/opt/app/config.rb'

node        = ARGV[0]
start_op    = ARGV[1]
failed_node = ARGV[2]

basho_bench_config   = $basho_bench_path + '/config'
basho_bench_template = 'riakc_pb.template'

# If we are replacing a failed node's config, set an identifying instance name
# and use the same start_op as the failed node
if(failed_node)
  my_node = "#{node}_#{failed_node}"
  start_op = %x(cat #{basho_bench_config}/#{failed_node}.read | grep key_generator | cut -f 4 -d',' | tr -d '[:space:]').to_s.strip
else
  my_node = node
end

# Create the Basho Bench configs from the template 
node_ip = $nodes[node][:ip].gsub!(/\./, ',')

text = File.read("#{basho_bench_config}/#{basho_bench_template}")
replace = text.gsub(/%IP%/, node_ip)
replace = replace.gsub(/%START_OP%/, start_op)
replace = replace.gsub(/%OPERATIONS%/, $num_operations.to_s)

{'read' => 'get', 'write' => 'put', 'delete' => 'delete'}.each do |operation, verb|
  output = replace.gsub(/%OPERATION%/, verb)
  File.open("#{basho_bench_config}/#{my_node}.#{operation}", 'w') { |file| file.puts output }
end

