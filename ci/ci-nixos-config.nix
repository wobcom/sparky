{ config, lib, pkgs, ... }:

{
  networking.hostName = "ci-test";

  system.stateVersion = "23.05";

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/44444444-4444-4444-8888-888888888888";
    fsType = "ext4";
  };

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "nodev";

  environment.systemPackages = [
    pkgs.sparky-web
    pkgs.prometheus-iperf3-exporter
  ];

  # enable all profiles to evaluate them
  profiles.sparky-headscale = {
    enable = true;
    metricsIP = "fdb0:34ac:df2e:2::1";
    probeSubnet = "fdb0:34ac:df2e:3::/64";
    fqdn = "sparky-headscale.example.com";
    derp = {
      enable = true;
      regionID = 999;
      regionCode = "example-isp";
      regionName = "Example-ISP Headscale DERP";
    };
  };

  profiles.sparky-metrics = {
    enable = true;
    fqdn = "sparky-metrics.example.com";
    webURL = "https://sparky.example.com";
    metricsApiKeyFile = "/invalid/path";
    probeSubnet = "fdb0:34ac:df2e:3::/64";
  };

  profiles.sparky-probe = {
    enable = true;
    ip = "fdb0:34ac:df2e:3::1";
    preAuthKey = "foobarbaz";
    headscaleIP = "fdb0:34ac:df2e:1::1";
    metricsIP = "fdb0:34ac:df2e:2::1";
    webURL = "https://sparky.example.com";
  };

  profiles.sparky-sd-mac = {
    enable = true;
    macInterfaceName = "foobar";
  };

  profiles.sparky-tailnet = {
    enable = true;
    ip = "fdb0:34ac:df2e:3::1";
    headscaleURL = "https://sparky-headscale.example.com";
  };

  profiles.sparky-web = {
    enable = true;
    enableLdap = true;
    ldapConfigPath = "/invalid/path";
    fqdn = "sparky.example.com";
    secretKeyFile = "/invalid/path";
    headscaleAPIKeyFile = "/invalid/path";
    probeRepoHost = "gitlab.com";
    probeRepoSSHCloneURL = "/invalid/path";
    propeRepoSSHDeployPrivKeyFile = "/invalid/path";
    propeRepoSSHDeployPubKeyFile = "/invalid/path";
    probeRepoAccessTokenFile = "/invalid/path";
    metricsApiKeyFile = "/invalid/path";
    extraConfig = ''
      HEADSCALE_URL = "https://sparky-headscale.example.com"
      PROBE_REPO_URL = "https://gitlab.com/api/v4/projects/XXXXX/repository/" # replace XXXXX with your GitLab project ID

      PROBE_NIXOS_STATE_VERSION = "23.05"

      PROBE_TAILNET_SUBNET = "fdb0:34ac:df2e:3::/64"

      PROBE_HOSTNAME_PREFIX = "probe"

      TIME_ZONE = 'Europe/Berlin'
    '';
  };

  profiles.sparky-ztp-image = {
    enable = true;
    webURL = "https://sparky.example.com";
    macInterfaceName = "foobar";
  };
}