node default {

  $app_home = "/vagrant"
  $app_install_script = "${app_home}/install_demo.sh"
  $app_config_file = "/opt/app/config.rb"

  $root_ssh_dir = "/root/.ssh"
  $demo_conf_dir = "/etc/basho-bench-demo"

  notify { "Building a ${::cluster_num_nodes} node Riak cluster on the ${::cluster_subnet}/24 network with an initial IP of ${::cluster_subnet}.${::cluster_initial_octet}." : }

  File {
    ensure  => present,
    mode    => 0644,
    owner   => "root",
    group   => "root",
  }

  Exec {
    timeout => 0,
  }

  package { "vim" :
    ensure => latest,
  }

  exec { $app_install_script :
    cwd     => $app_home,
    creates => "/root/basho-bench-gui-installed",
  }

  file { $root_ssh_dir :
    ensure  => directory,
    mode    => 0700,
    require => Exec[$app_install_script],
  }

  file { "/etc/ssh/ssh_config" :
    source  => "puppet:///files/ssh_config",
    require => Exec[$app_install_script],
  }

  file { "${root_ssh_dir}/id_rsa" :
    mode    => 0600,
    source  => "puppet:///files/id_riak_rsa",
    require => File[$root_ssh_dir],
  }

  file { $demo_conf_dir :
    ensure  => directory,
    mode    => 0755,
    require => Exec[$app_install_script],
  }

  file { "${demo_conf_dir}/nodes" :
    owner   => "root",
    group   => "root",
    content => template("nodes.erb"),
    require => File[$demo_conf_dir],
  }

  file { $app_config_file :
    require => Exec[$app_install_script],
    content => template("config.rb.erb"),
  }

  exec { "${app_home}/app/setup.rb" :
    require => File[$app_config_file],
  }

}

