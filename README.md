basho_bench_demo
===============

**Installation**

    $ git clone http://github.com/basho/basho_bench_demo
    $ cd basho_bench_demo
    $ sudo ./install_demo.sh

**Configuration**

1. Edit /opt/app/config.rb to set your node IPs and operation count
2. Run /opt/app/setup.rb

**Viewing the GUI**

Your GUI will be accessible at http://{IP_or_hostname}/demo

# Vagrant Setup

The Vagrantfile provided in the root directory of this project will create a VirtualBox virtual machine capable of driving this demonstration.  For rbenv users, an rbenv configuration is provided to ensure the proper version of Ruby is available.  For non-rbenv users, please ensure that Ruby v1.9.3 is installed and available.  For bundler users, executing `bundle install` will install the proper version of Vagrant and associated gems.  For non-bundler users, please ensure that Vagrant v1.0.5 is installed and available. By default, the vm will be configured as follows:

* cluster_subnet: 10.0.42
* cluster_initial_octet: 10
* cluster_number_nodes: 5
* http_forward_port: 8080

These defaults can be overidden by creating a vagrant.conf file in the root directory of this project and restating the parameter as a name-value pair.

Once the proper versions of Ruby and Vagrant are installed and configuration is complete, `vagrant up` will yield a VM capable per the instructions above that is capable of running the demonstration.  (Please note that this process will take a while -- particularly if run ion a machine with a small Internet connection)

