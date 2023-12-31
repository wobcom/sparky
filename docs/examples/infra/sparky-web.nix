{ config, lib, pkgs, ... }:

{
  sops.secrets = lib.genAttrs [
    "sparky-web-ldap-config"
    "sparky-web-secret-key"
    "sparky-web-headscale-api-key"
    "sparky-web-probe-repo-access-token"
    "sparky-web-probe-repo-privkey"
    "sparky-web-probe-repo-pubkey"
    "sparky-web-metrics-api-key"
  ] (_: {
    owner = "sparky-web";
    group = "sparky-web";
    mode = "0400";

    restartUnits = [ "sparky-web.service" ];
  });

  profiles.sparky-web = {
    enable = true;
    nginx = {
      default = true;
      forceSSL = true;
      enableACME = true;
    };
    enableLdap = true;
    ldapConfigPath = config.sops.secrets."sparky-web-ldap-config".path; # example LDAP config: see ./example-web-sops.yaml
    fqdn = "sparky.example.com";
    secretKeyFile = config.sops.secrets."sparky-web-secret-key".path;
    headscaleAPIKeyFile = config.sops.secrets."sparky-web-headscale-api-key".path;
    probeRepoHost = "gitlab.com"; # hostname of the gitlab server (used for ssh-keyscan)
    probeRepoSSHCloneURL = "git@gitlab.com:examplecom/sparky-probes.git"; # ssh clone URL of the probe repo
    propeRepoSSHDeployPrivKeyFile = config.sops.secrets."sparky-web-probe-repo-privkey".path;
    propeRepoSSHDeployPubKeyFile = config.sops.secrets."sparky-web-probe-repo-pubkey".path;
    probeRepoAccessTokenFile = config.sops.secrets."sparky-web-probe-repo-access-token".path;
    metricsApiKeyFile = config.sops.secrets."sparky-web-metrics-api-key".path;
    headscaleURL = "https://sparky-headscale.example.com";
    probeRepoURL = "https://gitlab.com/api/v4/projects/XXXXX/repository/"; # replace XXXXX with your GitLab project ID
    probeSubnet = "fdb0:34ac:df2e:3::/64";
    # example values for extra config: https://github.com/wobcom/sparky-web/blob/main/sparky_web/configuration.example.py
    extraConfig = ''
      ...
    '';
  };
}