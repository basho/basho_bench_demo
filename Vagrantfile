# -*- mode: ruby -*-
# vi: set ft=ruby :

# Read options into a hash from a configuration file
options = {
  :cluster_subnet => "10.0.42",
  :cluster_initial_octet => "10",
  :cluster_num_nodes => 5,
  :http_forward_port => 8080
}

conf_file_name = 'vagrant.conf'

override_options = []
override_options = Hash[*File.read(conf_file_name).split(/[= \n]+/)] unless not File.exists?(conf_file_name)

override_options.each_key { |key| options[key.to_sym] = override_options[key] }

Vagrant::Config.run do |config|
  # All Vagrant configuration is done here. The most common configuration
  # options are documented and commented below. For a complete reference,
  # please see the online documentation at vagrantup.com.

  # Every Vagrant virtual environment requires a box to build off of.
  config.vm.box = "precise64"

  # Forward a port from the guest to the host, which allows for outside
  # computers to access the VM, whereas host only networking does not.
  config.vm.forward_port 80, options[:http_forward_port].to_it fetch 

  config.vm.customize [
    "modifyvm", :id,
    "--memory", "1024",
    "--cpus", "2"
  ]

  config.vm.provision :puppet, :facter => {
    "cluster_subnet" => options[:cluster_subnet],
    "cluster_initial_octet" => options[:cluster_initial_octet],
    "cluster_num_nodes" => options[:cluster_num_nodes]
  } do |puppet|
    puppet.manifests_path = "config"
    puppet.manifest_file  = "site.pp"
    puppet.options = ["--templatedir","/tmp/vagrant-puppet/manifests/templates"]
  end

end
