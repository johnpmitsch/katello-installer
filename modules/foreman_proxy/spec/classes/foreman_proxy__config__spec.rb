require 'spec_helper'

describe 'foreman_proxy::config' do
  on_supported_os.each do |os, facts|
    context "on #{os}" do
      let(:facts) { facts }

      context 'without parameters' do
        let :pre_condition do
          'class {"foreman_proxy":}'
        end

        it { should compile.with_all_deps }

        it 'should include puppetca' do
          should contain_class('foreman_proxy::puppetca')
        end

        it 'should include tftp' do
          should contain_class('foreman_proxy::tftp')
        end

        it 'should not include dns' do
          should_not contain_class('foreman_proxy::proxydns')
        end

        it 'should not include dhcp' do
          should_not contain_class('foreman_proxy::proxydhcp')
        end

        it 'should create the foreman-proxy user' do
          should contain_user('foreman-proxy').with({
            :ensure  => 'present',
            :shell   => '/bin/false',
            :comment => 'Foreman Proxy account',
            :groups  => ['puppet'],
            :home    => '/usr/share/foreman-proxy',
            :require => 'Class[Foreman_proxy::Install]',
            :notify  => 'Class[Foreman_proxy::Service]',
          })
        end

        it 'should create configuration files' do
          ['/etc/foreman-proxy/settings.yml', '/etc/foreman-proxy/settings.d/tftp.yml', '/etc/foreman-proxy/settings.d/dns.yml',
            '/etc/foreman-proxy/settings.d/dhcp.yml', '/etc/foreman-proxy/settings.d/puppetca.yml', '/etc/foreman-proxy/settings.d/puppet.yml',
            '/etc/foreman-proxy/settings.d/bmc.yml', '/etc/foreman-proxy/settings.d/realm.yml', '/etc/foreman-proxy/settings.d/templates.yml'].each do |cfile|
            should contain_file(cfile).
              with({
                :owner   => 'root',
                :group   => 'foreman-proxy',
                :mode    => '0640',
                :require => 'Class[Foreman_proxy::Install]',
                :notify  => 'Class[Foreman_proxy::Service]',
              })
          end
        end

        it 'should generate correct settings.yml' do
          verify_exact_contents(catalogue, '/etc/foreman-proxy/settings.yml', [
            '---',
            ':settings_directory: /etc/foreman-proxy/settings.d',
            ':ssl_ca_file: /var/lib/puppet/ssl/certs/ca.pem',
            ":ssl_certificate: /var/lib/puppet/ssl/certs/#{facts[:fqdn]}.pem",
            ":ssl_private_key: /var/lib/puppet/ssl/private_keys/#{facts[:fqdn]}.pem",
            ':trusted_hosts:',
            "  - #{facts[:fqdn]}",
            ":foreman_url: https://#{facts[:fqdn]}",
            ':daemon: true',
            ':bind_host: \'*\'',
            ':https_port: 8443',
            ':virsh_network: default',
            ':log_file: /var/log/foreman-proxy/proxy.log',
            ':log_level: ERROR',
          ])
        end

        it 'should generate correct bmc.yml' do
          verify_exact_contents(catalogue, '/etc/foreman-proxy/settings.d/bmc.yml', [
            '---',
            ':enabled: false',
            ':bmc_default_provider: ipmitool',
          ])
        end

        it 'should generate correct dhcp.yml' do
          verify_exact_contents(catalogue, '/etc/foreman-proxy/settings.d/dhcp.yml', [
            '---',
            ':enabled: false',
            ':dhcp_vendor: isc',
          ])
        end

        it 'should generate correct dns.yml' do
          dns_key = case facts[:osfamily]
                    when 'Debian'
                      '/etc/bind/rndc.key'
                    else
                      '/etc/rndc.key'
                    end

          verify_exact_contents(catalogue, '/etc/foreman-proxy/settings.d/dns.yml', [
            '---',
            ':enabled: false',
            ':dns_provider: nsupdate',
            ':dns_server: 127.0.0.1',
            ':dns_ttl: 86400',
            ":dns_key: #{dns_key}",
          ])
        end

        it 'should generate correct puppet.yml' do
          verify_exact_contents(catalogue, '/etc/foreman-proxy/settings.d/puppet.yml', [
            '---',
            ':enabled: https',
            ':puppet_conf: /etc/puppet/puppet.conf',
            ':customrun_cmd: /bin/false',
            ':customrun_args: -ay -f -s',
            ':puppetssh_sudo: false',
            ':puppetssh_command: /usr/bin/puppet agent --onetime --no-usecacheonfailure',
            ':puppetssh_wait: false',
            ":puppet_url: https://#{facts[:fqdn]}:8140",
            ':puppet_ssl_ca: /var/lib/puppet/ssl/certs/ca.pem',
            ":puppet_ssl_cert: /var/lib/puppet/ssl/certs/#{facts[:fqdn]}.pem",
            ":puppet_ssl_key: /var/lib/puppet/ssl/private_keys/#{facts[:fqdn]}.pem",
          ])
        end

        it 'should generate correct puppetca.yml' do
          verify_exact_contents(catalogue, '/etc/foreman-proxy/settings.d/puppetca.yml', [
            '---',
            ':enabled: https',
            ':ssldir: /var/lib/puppet/ssl',
            ':puppetdir: /etc/puppet',
          ])
        end

        it 'should generate correct tftp.yml' do
          tftp_root = case facts[:osfamily]
                      when 'Debian'
                        case facts[:operatingsystem]
                        when 'Ubuntu'
                          '/var/lib/tftpboot/'
                        else
                          '/srv/tftp'
                        end
                      else
                        '/var/lib/tftpboot/'
                      end

          verify_exact_contents(catalogue, '/etc/foreman-proxy/settings.d/tftp.yml', [
            '---',
            ':enabled: https',
            ":tftproot: #{tftp_root}",
          ])
        end

        if facts[:osfamily] == 'Debian'
          case facts[:operatingsystemmajrelease]
          when '7'
            it 'should copy the correct default files for Debian 7' do
              should contain_foreman_proxy__tftp__copy_file('/usr/lib/syslinux/chain.c32')
              should contain_foreman_proxy__tftp__copy_file('/usr/lib/syslinux/menu.c32')
              should contain_foreman_proxy__tftp__copy_file('/usr/lib/syslinux/memdisk')
              should contain_foreman_proxy__tftp__copy_file('/usr/lib/syslinux/pxelinux.0')
            end
          when '8'
            it 'should copy the correct default files for Debian 8' do
              should contain_foreman_proxy__tftp__copy_file('/usr/lib/PXELINUX/pxelinux.0')
              should contain_foreman_proxy__tftp__copy_file('/usr/lib/syslinux/memdisk')
              should contain_foreman_proxy__tftp__copy_file('/usr/lib/syslinux/modules/bios/chain.c32')
              should contain_foreman_proxy__tftp__copy_file('/usr/lib/syslinux/modules/bios/ldlinux.c32')
              should contain_foreman_proxy__tftp__copy_file('/usr/lib/syslinux/modules/bios/libutil.c32')
              should contain_foreman_proxy__tftp__copy_file('/usr/lib/syslinux/modules/bios/menu.c32')
            end
          end
        end

        it 'should generate correct realm.yml' do
          verify_exact_contents(catalogue, '/etc/foreman-proxy/settings.d/realm.yml', [
            '---',
            ':enabled: false',
            ':realm_provider: freeipa',
            ':realm_keytab: /etc/foreman-proxy/freeipa.keytab',
            ':realm_principal: realm-proxy@EXAMPLE.COM',
            ':freeipa_remove_dns: true',
          ])
        end

        it 'should generate correct templates.yml' do
          verify_exact_contents(catalogue, '/etc/foreman-proxy/settings.d/templates.yml', [
            '---',
            ':enabled: false',
            ":template_url: http://#{facts[:fqdn]}:8000",
          ])
        end

        it 'should set up sudo rules' do
          should contain_file('/etc/sudoers.d').with_ensure('directory')

          should contain_file('/etc/sudoers.d/foreman-proxy').with({
            :ensure  => 'file',
            :owner   => 'root',
            :group   => 'root',
            :mode    => '0440',
            :require => 'File[/etc/sudoers.d]',
          })

          verify_exact_contents(catalogue, '/etc/sudoers.d/foreman-proxy', [
            "foreman-proxy ALL = (root) NOPASSWD : /usr/sbin/puppetca *",
            "foreman-proxy ALL = (root) NOPASSWD : /usr/sbin/puppetrun *",
            "Defaults:foreman-proxy !requiretty",
          ])
        end

        it 'should not manage /etc/sudoers.d' do
          should contain_file('/etc/sudoers.d').with_ensure('directory')
        end
      end

      context 'with custom foreman_ssl params' do
        let(:facts) { facts }

        let :pre_condition do
          'class {"foreman_proxy":
             foreman_ssl_ca   => "/etc/pki/ca.pem",
             foreman_ssl_cert => "/etc/pki/cert.pem",
             foreman_ssl_key => "/etc/pki/key.pem",
           }'
        end

        it 'should generate correct settings.yml' do
          verify_contents(catalogue, '/etc/foreman-proxy/settings.yml', [
            ":foreman_ssl_ca: /etc/pki/ca.pem",
            ":foreman_ssl_cert: /etc/pki/cert.pem",
            ":foreman_ssl_key: /etc/pki/key.pem"
          ])
        end
      end

      context 'with custom tftp parameters' do
        let :pre_condition do
          'class {"foreman_proxy":
            tftp_root       => "/tftproot",
            tftp_servername => "127.0.1.1",
          }'
        end

        it 'should generate correct tftp.yml' do
          verify_exact_contents(catalogue, '/etc/foreman-proxy/settings.d/tftp.yml', [
            '---',
            ':enabled: https',
            ':tftproot: /tftproot',
            ':tftp_servername: 127.0.1.1'
          ])
        end
      end

      context 'with bmc' do
        let :pre_condition do
          'class {"foreman_proxy":
            bmc                  => true,
            bmc_default_provider => "shell",
          }'
        end

        it 'should enable bmc with shell' do
          verify_contents(catalogue, '/etc/foreman-proxy/settings.d/bmc.yml', [
            ':enabled: https',
            ':bmc_default_provider: shell',
          ])
        end
      end

      context 'with TFTP enabled and tftp_syslinux_filenames set' do
        let :pre_condition do
          'class {"foreman_proxy":
            tftp => true,
            tftp_syslinux_filenames => [ "/my/file", "/my/anotherfile" ],
          }'
        end

        it 'should copy the given files' do
          should contain_foreman_proxy__tftp__copy_file('/my/file')
          should contain_foreman_proxy__tftp__copy_file('/my/anotherfile')
        end
      end

      context 'with pupppetrun_provider set to mcollective' do
        let :pre_condition do
          'class {"foreman_proxy":
            puppetrun          => true,
            puppetrun_provider => "mcollective",
          }'
        end

        it 'should contain mcollective as puppet_provider and puppet_user as root' do
          verify_contents(catalogue, '/etc/foreman-proxy/settings.d/puppet.yml', [
            ':puppet_provider: mcollective',
            ':puppet_user: root',
          ])
        end
      end

      context 'only http enabled' do
        let :pre_condition do
          'class {"foreman_proxy":
            ssl  => false,
            http => true,
          }'
        end

        it 'should comment out ssl configuration items' do
          verify_contents(catalogue, '/etc/foreman-proxy/settings.yml', [
            '#:ssl_ca_file: ssl/certs/ca.pem',
            '#:ssl_certificate: ssl/certs/fqdn.pem',
            '#:ssl_private_key: ssl/private_keys/fqdn.key',
            '#:https_port: 8443',
            ':http_port: 8000',
          ])
        end
      end

      context 'both http and ssl enabled' do
        let :pre_condition do
          'class {"foreman_proxy":
            ssl         => true,
            ssl_port    => 867,
            http        => true,
            http_port   => 5309,
          }'
        end

        it 'should configure both http and ssl on their respective ports' do
          verify_contents(catalogue, '/etc/foreman-proxy/settings.yml', [
            ':https_port: 867',
            ':http_port: 5309',
          ])
        end
      end

      context 'with deprecated parameters' do
        context 'with ssl => true' do
          let :pre_condition do
            'class {"foreman_proxy":
              ssl       => true,
              port      => 1234,
            }'
          end

          it 'should use port for ssl' do
            verify_contents(catalogue, '/etc/foreman-proxy/settings.yml', [
              ':https_port: 1234',
              '#:http_port: 1234',
            ])
          end
        end

        context 'with ssl => false' do
          let :pre_condition do
            'class {"foreman_proxy":
              ssl       => false,
              port      => 1234,
            }'
          end

          it 'should use port for http' do
            verify_contents(catalogue, '/etc/foreman-proxy/settings.yml', [
              '#:https_port: 1234',
              ':http_port: 1234',
            ])
          end
        end
      end

      context 'when dns_provider => nsupdate_gss' do
        let :pre_condition do
          'class {"foreman_proxy":
            dns_provider => "nsupdate_gss",
          }'
        end

        it 'should contain dns_tsig_* settings' do
          verify_contents(catalogue, '/etc/foreman-proxy/settings.d/dns.yml', [
            ':dns_tsig_keytab: /etc/foreman-proxy/dns.keytab',
            ":dns_tsig_principal: foremanproxy/#{facts[:fqdn]}@EXAMPLE.COM",
          ])
        end
      end

      context 'when puppetrun_provider => puppetrun' do
        let :pre_condition do
          'class {"foreman_proxy":
            puppetrun_provider => "puppetrun",
          }'
        end

        it 'should contain puppetrun as puppet_provider and puppet_user as root' do
          verify_contents(catalogue, '/etc/foreman-proxy/settings.d/puppet.yml', [
            ':puppet_provider: puppetrun',
            ':puppet_user: root',
          ])
        end
      end

      context 'when puppetrun_provider => puppetssh' do
        let :pre_condition do
          'class {"foreman_proxy":
            puppetrun_provider => "puppetssh",
          }'
        end

        it 'should set puppetssh_user and puppetssh_keyfile' do
          verify_contents(catalogue, '/etc/foreman-proxy/settings.d/puppet.yml', [
            ':puppetssh_user: root',
            ':puppetssh_keyfile: /etc/foreman-proxy/id_rsa',
          ])
        end
      end

      context 'when puppetrun_provider => salt' do
        let :pre_condition do
          'class {"foreman_proxy":
            puppetrun_provider => "salt",
          }'
        end

        it 'should contain salt as puppet_provider and salt_puppetrun_cmd' do
          verify_contents(catalogue, '/etc/foreman-proxy/settings.d/puppet.yml', [
            ':puppet_provider: salt',
            ':salt_puppetrun_cmd: puppet.run',
          ])
        end
      end

      context 'when puppet_use_environment_api set' do
        let :pre_condition do
          'class {"foreman_proxy":
            puppet_use_environment_api => false,
          }'
        end

        it 'should set puppet_use_environment_api' do
          verify_contents(catalogue, '/etc/foreman-proxy/settings.d/puppet.yml', [
            ':puppet_use_environment_api: false',
          ])
        end
      end

      context 'when trusted_hosts is empty' do
        let :pre_condition do
          'class {"foreman_proxy":
            trusted_hosts => [],
          }'
        end

        it 'should not set trusted_hosts' do
          should contain_file('/etc/foreman-proxy/settings.yml').without_content(/[^#]:trusted_hosts/)
        end
      end

      context 'with custom foreman_base_url' do
        let :pre_condition do
          'class {"foreman_proxy":
             foreman_base_url => "http://dummy",
           }'
        end

        it 'should generate foreman_url setting' do
          content = catalogue.resource('file', '/etc/foreman-proxy/settings.yml').send(:parameters)[:content]
          content.split("\n").select { |c| c =~ /foreman_url/ }.should == [':foreman_url: http://dummy']
        end
      end

      context 'when puppetca_cmd set' do
        let :pre_condition do
          'class { "foreman_proxy":
            puppetca_cmd => "puppet cert",
          }'
        end

        it "should set puppetca_cmd" do
          verify_exact_contents(catalogue, '/etc/sudoers.d/foreman-proxy', [
            "foreman-proxy ALL = (root) NOPASSWD : puppet cert *",
            "foreman-proxy ALL = (root) NOPASSWD : /usr/sbin/puppetrun *",
            "Defaults:foreman-proxy !requiretty",
          ])
        end
      end

      context 'when puppetrun_cmd set' do
        let :pre_condition do
          'class { "foreman_proxy":
            puppetrun_cmd => "mco puppet runonce",
          }'
        end

        it "should set puppetrun_cmd" do
          verify_exact_contents(catalogue, '/etc/sudoers.d/foreman-proxy', [
            "foreman-proxy ALL = (root) NOPASSWD : /usr/sbin/puppetca *",
            "foreman-proxy ALL = (root) NOPASSWD : mco puppet runonce *",
            "Defaults:foreman-proxy !requiretty",
          ])
        end
      end

      context 'when puppet_user set' do
        let :pre_condition do
          'class { "foreman_proxy":
            puppet_user => "foreman-proxy",
          }'
        end

        it "should set puppetrun_cmd" do
          verify_exact_contents(catalogue, '/etc/sudoers.d/foreman-proxy', [
            "foreman-proxy ALL = (root) NOPASSWD : /usr/sbin/puppetca *",
            "foreman-proxy ALL = (foreman-proxy) NOPASSWD : /usr/sbin/puppetrun *",
            "Defaults:foreman-proxy !requiretty",
          ])
        end
      end

      context 'when puppetca disabled' do
        let :pre_condition do
          'class { "foreman_proxy":
            puppetca => false,
          }'
        end

        it "should not set puppetca" do
          verify_exact_contents(catalogue, '/etc/sudoers.d/foreman-proxy', [
            "foreman-proxy ALL = (root) NOPASSWD : /usr/sbin/puppetrun *",
            "Defaults:foreman-proxy !requiretty",
          ])
        end
      end

      context 'when puppetrun disabled' do
        let :pre_condition do
          'class { "foreman_proxy":
            puppetrun => false,
          }'
        end

        it "should not set puppetrun" do
          verify_exact_contents(catalogue, '/etc/sudoers.d/foreman-proxy', [
            "foreman-proxy ALL = (root) NOPASSWD : /usr/sbin/puppetca *",
            "Defaults:foreman-proxy !requiretty",
          ])
        end
      end

      context 'when puppetca and puppetrun disabled' do
        let :pre_condition do
          'class { "foreman_proxy":
            puppetca  => false,
            puppetrun => false,
          }'
        end

        it { should_not contain_file('/etc/sudoers.d') }
        it { should_not contain_file('/etc/sudoers.d/foreman-proxy') }
      end

      context 'when use_sudoersd => false' do
        let :pre_condition do
          'class {"foreman_proxy":
            use_sudoersd => false,
          }'
        end

        it "should not manage /etc/sudoers.d" do
          should_not contain_file('/etc/sudoers.d')
        end

        it "should not manage /etc/sudoers.d/foreman-proxy" do
          should_not contain_file('/etc/sudoers.d/foreman-proxy')
        end

        it "should modify /etc/sudoers" do
          should contain_augeas('sudo-foreman-proxy').with({
            :context  => '/files/etc/sudoers',
          })

          changes = catalogue.resource('augeas', 'sudo-foreman-proxy').send(:parameters)[:changes]
          changes.split("\n").should == [
            "set spec[user = 'foreman-proxy'][1]/user foreman-proxy",
            "set spec[user = 'foreman-proxy'][1]/host_group/host ALL",
            "set spec[user = 'foreman-proxy'][1]/host_group/command '/usr/sbin/puppetca *'",
            "set spec[user = 'foreman-proxy'][1]/host_group/command/runas_user root",
            "set spec[user = 'foreman-proxy'][1]/host_group/command/tag NOPASSWD",
            "set spec[user = 'foreman-proxy'][2]/user foreman-proxy",
            "set spec[user = 'foreman-proxy'][2]/host_group/host ALL",
            "set spec[user = 'foreman-proxy'][2]/host_group/command '/usr/sbin/puppetrun *'",
            "set spec[user = 'foreman-proxy'][2]/host_group/command/runas_user root",
            "set spec[user = 'foreman-proxy'][2]/host_group/command/tag NOPASSWD",
            "rm spec[user = 'foreman-proxy'][1]/host_group/command[position() > 1]",
            "set Defaults[type = ':foreman-proxy']/type :foreman-proxy",
            "set Defaults[type = ':foreman-proxy']/requiretty/negate ''",
          ]
        end

        context 'when puppetca => false' do
          let :pre_condition do
            'class {"foreman_proxy":
              use_sudoersd => false,
              puppetca     => false,
            }'
          end

          it "should modify /etc/sudoers for puppetrun only" do
            changes = catalogue.resource('augeas', 'sudo-foreman-proxy').send(:parameters)[:changes]
            changes.split("\n").should == [
              "set spec[user = 'foreman-proxy']/user foreman-proxy",
              "set spec[user = 'foreman-proxy']/host_group/host ALL",
              "set spec[user = 'foreman-proxy']/host_group/command '/usr/sbin/puppetrun *'",
              "set spec[user = 'foreman-proxy']/host_group/command/runas_user root",
              "set spec[user = 'foreman-proxy']/host_group/command/tag NOPASSWD",
              "rm spec[user = 'foreman-proxy'][1]/host_group/command[position() > 1]",
              "set Defaults[type = ':foreman-proxy']/type :foreman-proxy",
              "set Defaults[type = ':foreman-proxy']/requiretty/negate ''",
            ]
          end
        end

        context 'when puppetrun => false' do
          let :pre_condition do
            'class {"foreman_proxy":
              use_sudoersd => false,
              puppetrun    => false,
            }'
          end

          it "should modify /etc/sudoers for puppetca only" do
            changes = catalogue.resource('augeas', 'sudo-foreman-proxy').send(:parameters)[:changes]
            changes.split("\n").should == [
              "set spec[user = 'foreman-proxy']/user foreman-proxy",
              "set spec[user = 'foreman-proxy']/host_group/host ALL",
              "set spec[user = 'foreman-proxy']/host_group/command '/usr/sbin/puppetca *'",
              "set spec[user = 'foreman-proxy']/host_group/command/runas_user root",
              "set spec[user = 'foreman-proxy']/host_group/command/tag NOPASSWD",
              "rm spec[user = 'foreman-proxy'][1]/host_group/command[position() > 1]",
              "set Defaults[type = ':foreman-proxy']/type :foreman-proxy",
              "set Defaults[type = ':foreman-proxy']/requiretty/negate ''",
            ]
          end
        end
      end

      context 'with feature on http' do
        let :pre_condition do
          'class {"foreman_proxy":
            templates           => true,
            templates_listen_on => "http",
          }'
        end

        it 'should set enabled to http' do
          verify_contents(catalogue, '/etc/foreman-proxy/settings.d/templates.yml', [
            ':enabled: http',
          ])
        end
      end

      context 'with feature on https' do
        let :pre_condition do
          'class {"foreman_proxy":
            templates           => true,
            templates_listen_on => "https",
          }'
        end

        it 'should set enabled to https' do
          verify_contents(catalogue, '/etc/foreman-proxy/settings.d/templates.yml', [
            ':enabled: https',
          ])
        end
      end

      context 'with feature on both' do
        let :pre_condition do
          'class {"foreman_proxy":
            templates           => true,
            templates_listen_on => "both",
          }'
        end

        it 'should set enabled to true' do
          verify_contents(catalogue, '/etc/foreman-proxy/settings.d/templates.yml', [
            ':enabled: true',
          ])
        end
      end

      context 'when log_level => DEBUG' do
        let :pre_condition do
          'class {"foreman_proxy":
            log_level => "DEBUG",
          }'
        end

        it 'should set log_level to DEBUG in setting.yml' do
          verify_contents(catalogue, '/etc/foreman-proxy/settings.yml', [
            ':log_level: DEBUG',
          ])
        end
      end

      context 'with puppet use_cache enabled' do
        let :pre_condition do
          'class {"foreman_proxy":
            puppet_use_cache => true,
          }'
        end

        it 'should create the cache_location' do
          should contain_file('/var/cache/foreman-proxy').with_ensure('directory')
        end

        it 'should set use_cache and cache_location' do
          verify_contents(catalogue, '/etc/foreman-proxy/settings.d/puppet.yml', [
            ':use_cache: true',
            ":cache_location: '/var/cache/foreman-proxy'",
          ])
        end
      end

      context 'with dhcp enabled' do
        let :facts do
          facts.merge({
            :concat_basedir => '/doesnotexist',
          })
        end

        let :pre_condition do
          'class {"foreman_proxy":
            dhcp           => true,
            dhcp_interface => "lo",
          }'
        end

        dhcp_leases = case facts[:osfamily]
                      when 'Debian'
                        '/var/lib/dhcp/dhcpd.leases'
                      else
                        '/var/lib/dhcpd/dhcpd.leases'
                      end

        it 'should generate correct dhcp.yml' do
          verify_exact_contents(catalogue, '/etc/foreman-proxy/settings.d/dhcp.yml', [
            '---',
            ':enabled: https',
            ':dhcp_vendor: isc',
            ':dhcp_config: /etc/dhcp/dhcpd.conf',
            ":dhcp_leases: #{dhcp_leases}",
            ':dhcp_omapi_port: 7911',
          ])
        end
      end
    end
  end
end
