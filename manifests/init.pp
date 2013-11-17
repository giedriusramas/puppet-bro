class bro(
  $ensure       = $bro::params::ensure,
  $pf_cid       = $bro::params::pf_cid,
  $debug        = $bro::params::debug,
  $mailto       = $bro::params::mailto,
  $sitepolicy   = $bro::params::sitepolicy,
  $logexpire    = $bro::params::logexpire,
  $mindisk      = $bro::params::mindisk,
  $logrotate    = $bro::params::logrotate,
  $pkg_ensure   = $bro::params::pkg_ensure,
  $pkg_source   = $bro::params::pkg_source,
  $basedir      = $bro::params::basedir,
  $logdir       = $bro::params::logdir,
  $logrotation  = $bro::params::logrotation,
  $manager      = $bro::params::manager,
  $proxy        = $bro::params::proxy,
  $worker       = $bro::params::worker,
  $int          = $bro::params::interface,
  $bro_pkg_name = $bro::params::bro_pkg_name,
  $bro_url      = $bro::params::bro_url,
  $type         = $bro::params::type,
  $network      = $bro::params::network,
  ) inherits bro::params {
  if ( $ensure == 'running' ) {
    $bro_present = 'present'
    $bro_state  = 'running'
  } else {
    $bro_present = 'absent'
    $bro_state  = 'stopped'
  }
  class {'bro::pkg':}
  class {'bro::broctl':}
  File {
    ensure  => present,
    mode    => '0644',
    owner   => '0',
    group   => '0',
    require => Exec['create_base'],
  }
  exec { 'create_base':
    command => "mkdir -p $basedir",
    creates => $basedir,
    path    => ['/bin','/sbin','/usr/sbin','/usr/bin'],
  }
  $if_dirs = [
    "$basedir",
    "$basedir/bin",
    "$basedir/share",
    "$basedir/share/bro",
  ]
  if ! defined_with_params(File[$if_dirs], {'ensure' => 'directory' }) {
    file { $if_dirs: ensure => directory, }
  }
  $bro_dirs = [
    "$basedir/share/bro/site",
    "$basedir/etc"
  ]
  file { $bro_dirs:
    ensure  => directory,
    recurse => true,
    purge   => true,
    force   => true,
  }
  file { 'scripts':
    name    => "$basedir/share/bro/site/scripts",
    recurse => true,
    purge   => true,
    force   => true,
    source  => "puppet:///modules/bro/scripts",
    notify  => Service['wassup_bro'],
  }
  $localbro_default = "puppet:///modules/bro/localbro/$sitepolicy"
  $localbro_custom = "puppet:///modules/bro/localbro/local.bro.$::hostname"
  file { "$basedir/share/bro/site/local.bro":
    source => [ "$localbro_custom","$localbro_default" ],
    notify => Service['wassup_bro'],
  }
  file { "$basedir/bin/bro_cron":
    mode => '0755',
    content => template('bro/bro_cron.erb'),
  }
  cron { 'bro_cron':
    ensure  => $bro_present,
    command => "$basedir/bin/bro_cron",
    user    => '0',
    minute  => '*/5',
  }
  file { "$basedir/bin/wassup_bro":
    mode => '0755',
    content => template('bro/wassup_bro.erb'),
  }
  $status  = "$basedir/bin/wassup_bro status | grep running"
  $start   = "$basedir/bin/wassup_bro start"
  $stop    = "$basedir/bin/wassup_bro stop"
  $restart = "$basedir/bin/wassup_bro restart"
  service { 'wassup_bro':
    ensure  => $bro_state,
    status  => $status,
    start   => $start,
    restart => $restart,
    stop    => $stop,
    require => File["$basedir/bin/wassup_bro"],
  }
  $node_conf = "${basedir}/etc/node.cfg"
  if ($type == 'cluster') {
    concat { $node_conf:
      owner   => '0',
      group   => '0',
      mode    => '0644',
      notify  => Service['wassup_bro'],
    }
    concat::fragment { 'node_conf_header':
      target  => $node_conf,
      content => "# CONFIG MANAGED BY PUPPET\n\n",
      order   => 01,
    }
    concat::fragment { 'node_conf_manager':
      target  => $node_conf,
      content => template('bro/manager_name.erb'),
      order   => 02,
    }
    concat::fragment { 'node_conf_proxy':
      target  => $node_conf,
      content => template('bro/proxy_name.erb'),
      order   => 03,
    }
  } else {
    file { "${node_conf}":
      content => template('bro/node.cfg.erb'),
      notify  => Service['wassup_bro'],
    }
  }
  file { "${basedir}/etc/networks.cfg":
    content => template('bro/networks.cfg.erb'),
    notify  => Service['wassup_bro'],
  }
  file { '/opt/bro/share/bro/site/local-manager.bro':
    content => "# Manager\n",
  }
  file { '/opt/bro/share/bro/site/local-proxy.bro':
    content => "# Proxy\n",
  }
  file { '/opt/bro/share/bro/site/local-worker.bro':
    content => "# Worker\n",
  }
}