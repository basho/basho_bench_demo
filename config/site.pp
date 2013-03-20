node default {

  $app_home = "/vagrant"
  $app_install_script = "${app_home}/install_demo.sh"
  $app_config_file = "/opt/app/config.rb"

  notify { "Building a ${::cluster_num_nodes} node Riak cluster on the ${::cluster_subnet}/24 network with an initial IP of ${::cluster_subnet}.${::cluster_initial_octet}." : }

  package { "vim" :
    ensure => latest,
  }

  exec { $app_install_script :
    cwd => $app_home,
    timeout => 0,
    creates => "/root/basho-bench-gui-installed",
  }

  file { $app_config_file :
    ensure  => present,
    require => Exec[$app_install_script],
    content => template("config.rb.erb"),
  }

  exec { "${app_home}/app/setup.rb" :
    timeout => 0,
    require => File[$app_config_file],
  }

}

