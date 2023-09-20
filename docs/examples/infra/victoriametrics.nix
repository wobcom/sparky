{ config, lib, pkgs, ... }:

{
  sops.secrets = {
    "metrics-api-key" = {
      owner = "vmauth";
      group = "vmauth";
      mode = "0400";
    };
    # optional
    "htpasswd" = {
      owner = "nginx";
      group = "nginx";
      mode = "0400";

      restartUnits = [ "nginx.service" ];
    };
  };

  profiles.sparky-tailnet = {
    enable = true;
    ip = "fd8f:89ae:ca73:2::1";
    preAuthKey = "your generated preauthkey";
  };
  
  profiles.sparky-metrics = {
    enable = true;
    fqdn = "sparky-metrics.example.com";
    webURL = "https://sparky.example.com";
    metricsApiKeyFile = config.sops.secrets."metrics-api-key".path;
    probeSubnet = "fd8f:89ae:ca73:3::/64";
    nginx = {
      default = true;
      forceSSL = true;
      enableACME = true;
      basicAuthFile = config.sops.secrets."htpasswd".path; # optional
    };
  };
}