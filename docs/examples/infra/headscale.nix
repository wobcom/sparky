{ config, lib, pkgs, ... }:

{
  profiles.sparky-headscale = {
    enable = true;
    metricsIP = "fd8f:89ae:ca73:2::1";
    probeSubnet = "fd8f:89ae:ca73:3::/64";
    fqdn = "sparky-headscale.example.com"; # will be used for HTTPS-Requests, so public resolution is required here
    derp = {
      # see https://tailscale.com/kb/1232/derp-servers/
      enable = true;
      regionID = 999;
      regionCode = "example-isp";
      regionName = "Example-ISP Headscale DERP";
    };
    nginx = {
      default = true;
      forceSSL = true;
      enableACME = true;
    };
  };

  # as described in the readme, the headscale server is also
  # in the tailnet as a SSH jump-host to the probes
  # NOTE: this won't work on initial deployment as the headscale needs to be configured first
  profiles.sparky-tailnet = {
    enable = true;
    ip = "fd8f:89ae:ca73:1::1";
    headscaleURL = "https://sparky-headscale.example.com"; # HTTPS to the configured FQDN above
    preAuthKey = "generated pre auth key"; # insert your pre-auth-key here after you have configured your headscale (see readme)
  };
}