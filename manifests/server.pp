class managerootpw::server {

  # This class MUST run on the puppet server (because of the "generate" in
  # the init.pp)

  file {
    '/usr/local/sbin/managerootpw.sh':
      ensure => 'present',
      mode   => '0755',
      owner  => 'root',
      group  => 'root',
      source => 'puppet:///modules/managerootpw/usr/local/sbin/managerootpw.sh';

    '/var/lib/managerootpw':
      ensure => 'directory',
      mode   => '700',
      owner  => 'puppet',
      group  => 'root';
  }

  case $managerootpw::frequency {
    'daily': {
      $monthday = '*'
      $weekday  = '*'
    }
    'weekly': {
      $monthday = '*'
      $weekday  = '1'
    }
    'monthly': {
      $monthday = '1'
      $weekday  = '*'
    }
    default: {
      fail("Unknown value: ${managerootpw::frequency}")
    }
  }

  cron { 'generate-rootpws':
    command  => "/usr/local/sbin/managerootpw.sh -s -l ${managerootpw::pwlength} -a ${managerootpw::saltlength} -r ${managerootpw::retain}",
    user     => 'puppet',
    hour     => '5',
    minute   => '0',
    monthday => $monthday,
    weekday  => $weekday,
  }

}
