# == Class: cvmfs::config
#
# Configures generic configuration for all cvmfs mounts.
#
# === Authors
#
# Steve Traylen <steve.traylen@cern.ch>
#
# === Copyright
#
# Copyright 2012 CERN
#
class cvmfs::config (
  $config_automaster  = $cvmfs::config_automaster,
  $cvmfs_quota_limit  = $cvmfs::cvmfs_quota_limit,
  $cvmfs_quota_ratio  = $cvmfs::cvmfs_quota_ratio,
  $default_cvmfs_partsize = $cvmfs::default_cvmfs_partsize,
) inherits cvmfs {

  # If cvmfspartsize fact exists use it, otherwise use a sensible default. 
  if getvar(::cvmfspartsize) {
    $_cvmfs_partsize = $::cvmfspartsize
  } else {
    $_cvmfs_partsize = $default_cvmfs_partsize
  }


  case $cvmfs_quota_limit {
    'auto':  { $my_cvmfs_quota_limit = sprintf('%i',$cvmfs_quota_ratio *  $_cvmfs_partsize) }
    default: { $my_cvmfs_quota_limit = $cvmfs_quota_limit }
  }

  # Clobber the /etc/cvmfs/domain.d directory.
  # This puppet module just does not support
  # concept of this directory so it's safer to clean it.
  file{'/etc/cvmfs/domain.d':
    ensure  => directory,
    purge   => true,
    recurse => true,
    ignore  => '*.conf',
    require => Package['cvmfs'],
    owner   => root,
    group   => root,
    mode    => '0755',
  }
  file{'/etc/cvmfs/domain.d/README.PUPPET':
    ensure  => file,
    owner   => root,
    group   => root,
    mode    => '0644',
    content => "This directory is managed by puppet but *.conf files are ignored from purging\n",
    require => File['/etc/cvmfs/domain.d'],
  }

  # Clobber the /etc/fuse.conf, hopefully no
  # one else wants it.
  file{'/etc/fuse.conf':
    ensure  => present,
    content => "#Installed with puppet cvmfs::config\nuser_allow_other\n",
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    notify  => Class['cvmfs::service'],
  }
  concat{'/etc/cvmfs/default.local':
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    require => Class['cvmfs::install'],
    notify  => Class['cvmfs::service'],
  }
  concat::fragment{'cvmfs_default_local_header':
    target  => '/etc/cvmfs/default.local',
    order   => 0,
    content => template('cvmfs/repo.local.erb'),
  }

  if str2bool($config_automaster) {
    augeas{'cvmfs_automaster':
      context => '/files/etc/auto.master/',
      lens    => 'Automaster.lns',
      incl    => '/etc/auto.master',
      changes => [
        'set 01      /cvmfs',
        'set 01/type program',
        'set 01/map  /etc/auto.cvmfs',
      ],
      onlyif  => 'match *[map="/etc/auto.cvmfs"] size == 0',
      notify  => Service['autofs'],
    }
  }
}
