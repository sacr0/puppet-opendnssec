# frozen_string_literal: true

require 'spec_helper_acceptance'

describe 'opendnssec dns adapter to file adapter', tier_low: true do
  context 'defaults' do
    if fact('osfamily') == 'RedHat'
      enforcer = 'ods-enforcerd'
      signer = 'ods-signerd'
      base_dir = '/var/opendnssec'
    else
      enforcer = 'opendnssec-enforcer'
      signer = 'opendnssec-signer'
      base_dir = '/var/lib/opendnssec'
    end
    it 'work with no errors' do
      pp = <<-EOF
      class {'::softhsm':
        tokens => {
          'OpenDNSSEC' => {
            'pin'    => '1234',
            'so_pin' => '1234',
          },
        },
      }
      class {'::opendnssec':
        zones => {
          'root-servers.net' => {
            'masters' => [
              'lax.xfr.dns.icann.org',
              'iad.xfr.dns.icann.org',
            ],
            'adapter_output_type' => 'File'
          },
        },
        remotes  => {
          'lax.xfr.dns.icann.org' => {
            'address4' => '192.0.32.132',
            'address6' => '2620:0:2d0:202::132',
          },
          'iad.xfr.dns.icann.org' => {
            'address4' => '192.0.47.132',
            'address6' => '2620:0:2830:202::132',
          },
          'localhost' => { 'address4' => '127.0.0.1', },
        },
      }
      EOF
      apply_manifest(pp, catch_failures: true)
      apply_manifest(pp, catch_failures: true)
      expect(apply_manifest(pp, catch_failures: true).exit_code).to eq 0
    end
    describe service(enforcer) do
      it { is_expected.to be_running }
    end
    describe service(signer) do
      it { is_expected.to be_running }
    end
    describe port(53) do
      it { is_expected.to be_listening }
    end
    describe command('/usr/bin/ods-ksmutil repository list') do
      its(:stdout) { is_expected.to match(%r{SoftHSM\s+0\s+No}) }
    end
    describe command('/usr/bin/ods-ksmutil policy list') do
      its(:stdout) do
        is_expected.to match(
          %r{default\s+default - Deny:NSEC3; KSK:RSASHA1-NSEC3-SHA1; ZSK:RSASHA1-NSEC3-SHA1},
        )
      end
    end
    describe command('/usr/bin/ods-ksmutil zone list') do
      its(:stdout) do
        is_expected.to match('Found Zone: root-servers.net; on policy default')
      end
    end
    describe command('/usr/bin/ods-ksmutil key list') do
      its(:stdout) { is_expected.to match(%r{root-servers.net\s+KSK\s+publish}) }
      its(:stdout) { is_expected.to match(%r{root-servers.net\s+ZSK\s+active}) }
    end
    describe command('/usr/sbin/ods-signer zones') do
      its(:stdout) { is_expected.to match('root-servers.net') }
    end
    describe command(
      "/bin/grep RRSIG #{base_dir}/signed/root-servers.net",
    ) do
      its(:exit_status) { is_expected.to eq 0 }
    end
  end
end
