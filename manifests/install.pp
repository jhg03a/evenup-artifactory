# == Class: artifactory::install
#
# This class installs artifactory.  It should not be called directly
#
#
# === Authors
#
# * Justin Lambert <mailto:jlambert@letsevenup.com>
#
class artifactory::install {

  if $caller_module_name != $module_name {
    fail("Use of private class ${name} by ${caller_module_name}")
  }

  if $::artifactory::manage_repo {
    case $::osfamily {
      'Debian': {
        apt::key { 'artifactory':
          key        => 'A3D085F542F740BBD7E3A2846B219DCCD7639232',
          key_source => 'https://bintray.com/user/downloadSubjectPublicKey?username=jfrog',
        }

        apt::source { 'artifactory-oss':
          comment     => 'Artifactory open source repository',
          location    => 'https://bintray.com/artifact/download/jfrog/artifactory-debs',
          repos       => 'main',
          include_deb => true,
          key         => 'A3D085F542F740BBD7E3A2846B219DCCD7639232',
          key_server  => 'keyserver.ubuntu.com',
        }

        apt::source { 'artifactory-pro':
          comment     => 'Artifactory Pro repository',
          location    => 'https://jfrog.bintray.com/artifactory-pro-debs',
          repos       => 'main',
          include_deb => true,
          key         => 'A3D085F542F740BBD7E3A2846B219DCCD7639232',
          key_server  => 'pgp.mit.edu',
        }
      }
      'RedHat': {
        yumrepo { 'artifactory':
          baseurl => 'http://jfrog.bintray.com/artifactory-pro-rpms',
          descr   => 'Artifactory by JFrog repository',
          enabled => true,
        }
      }
      default: {
        fail('Artifactory repository management for this osfamily is unsupported')
      }
    }
  }

  if $::artifactory::manage_user {
    user { 'artifactory':
      ensure => 'present',
      system => true,
      shell  => '/bin/bash',
      home   => $::artifactory::home_dir,
      gid    => 'artifactory',
    }

    group { 'artifactory':
      ensure => 'present',
      system => true,
    }
  }

  package { 'artifactory':
    ensure   => $::artifactory::ensure,
    name     => $::artifactory::package_name,
    provider => $::artifactory::package_provider,
    source   => $::artifactory::package_source,
    notify   => Class['artifactory::service'],
    require  => [ User['artifactory'], Group['artifactory'] ],
  }

  file {$::artifactory::home_dir:
    ensure  => directory,
    recurse => true,
    owner   => artifactory,
    group   => artifactory,
    require => Package['artifactory'],
  }

  if $::artifactory::data_path != "${::artifactory::home_dir}/data" {
    File <| title == $::artifactory::data_path |> {
      ensure => directory,
      mode   => '0775',
      owner  => artifactory,
      group  => artifactory,
    }

    file { "${::artifactory::home_dir}/data":
      ensure => link,
      target => $::artifactory::data_path,
      owner  => artifactory,
      group  => artifactory,
    }
  }

  if $::artifactory::backup_path {
    file { $::artifactory::backup_path:
      ensure => directory,
      mode   => '0775',
      owner  => artifactory,
      group  => artifactory,
    }
  }

  if $::artifactory::db_type == 'postgresql' {
    $is_valid_jdbc_url_regex = '.*\/(.*\.jar)$'
    if $::artifactory::postgresql_jdbc_url =~ $is_valid_jdbc_url_regex {
      $pql_driver = regsubst($::artifactory::postgresql_jdbc_url,$is_valid_jdbc_url_regex,'\1')
      file { "${::artifactory::home_dir}/tomcat/lib":
        ensure => directory,
        mode   => '0775',
        owner  => artifactory,
        group  => artifactory,
      } ->
      file {'Postgresql JDBC Driver':
        ensure => 'file',
        path   => "${::artifactory::home_dir}/tomcat/lib/${pql_driver}",
        source => $::artifactory::postgresql_jdbc_url,
        mode   => '0775',
        owner  => artifactory,
        group  => artifactory,
        notify => Service['artifactory'],
      }
    } else {
      fail("The Postgresql JDBC Driver URL doesn't look correct. (${::artifactory::postgresql_jdbc_url})")
    }
  }
}
