{ config, lib, pkgs, modulesPath, ... }:

with lib;

let
  cfg = config.profiles.sparky-web;
  configFile = pkgs.writeTextFile {
    name = "configuration.py";
    text = ''
      ALLOWED_HOSTS = ['*']
      DATABASE = {
        'ENGINE': 'django.db.backends.postgresql_psycopg2',
        'NAME': 'sparky-web',
        'USER': 'sparky-web',
        'HOST': '/run/postgresql',
      }

      PROBE_REPO_LOCAL_PATH = "/var/lib/sparky-web/probe-repo"

      with open("${cfg.secretKeyFile}", "r") as file:
        SECRET_KEY = file.readline()

      with open("${cfg.headscaleAPIKeyFile}", "r") as file:
        HEADSCALE_API_KEY = file.readline()

      with open("${cfg.probeRepoAccessTokenFile}", "r") as file:
        PROBE_REPO_ACCESS_TOKEN = file.readline()

      with open("${cfg.metricsApiKeyFile}", "r") as file:
        METRICS_API_KEY = file.readline()

      HEADSCALE_URL = "${cfg.headscaleURL}"
      PROBE_REPO_URL = "${cfg.probeRepoURL}"

      PROBE_NIXOS_STATE_VERSION = "${cfg.probeNixOSStateVersion}"

      PROBE_TAILNET_SUBNET = "${cfg.probeSubnet}"

      PROBE_HOSTNAME_PREFIX = "${cfg.probeHostnamePrefix}"

      TIME_ZONE = '${if config.time.timeZone != null then config.time.timeZone else "UTC"}'

      ${cfg.extraConfig}
    '';
  };
  pkg = (pkgs.sparky-web.overrideAttrs (old: {
    postInstall = ''
      ln -s ${configFile} $out/opt/sparky-web/sparky_web/configuration.py
    '' + optionalString cfg.enableLdap ''
      ln -s ${cfg.ldapConfigPath} $out/opt/sparky-web/sparky_web/ldap_config.py
    '';
  })).override {
    inherit (cfg) plugins;
  };
  sparkyWebManageScript = with pkgs; (writeScriptBin "sparky-web-manage" ''
    #!${stdenv.shell}
    export PYTHONPATH=${pkg.pythonPath}
    sudo -u sparky-web ${pkg}/bin/sparky-web "$@"
  '');

in {
  options.profiles.sparky-web = {
    enable = mkOption {
      type = lib.types.bool;
      default = false;
      description = mdDoc ''
        Enable the SPARKY-Web profile.
      '';
    };

    listenAddress = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = mdDoc ''
        Address the server will listen on.
      '';
    };

    port = mkOption {
      type = types.port;
      default = 8001;
      description = mdDoc ''
        Port the server will listen on.
      '';
    };

    fqdn = mkOption {
      type = types.str;
      description = mdDoc ''
        The FQDN for the nginx vHost of SPARKY-Web.
      '';
    };

    plugins = mkOption {
      type = types.functionTo (types.listOf types.package);
      default = _: [];
      defaultText = literalExpression ''
        python3Packages: with python3Packages; [];
      '';
      description = lib.mdDoc ''
        List of plugin packages to install.
      '';
    };

    enableLdap = mkOption {
      type = types.bool;
      default = false;
      description = lib.mdDoc ''
        Enable LDAP-Authentication for SPARKY-Web.

        This requires a configuration file being pass through `ldapConfigPath`.
      '';
    };

    ldapConfigPath = mkOption {
      type = types.path;
      description = lib.mdDoc ''
        Path to the Configuration-File for LDAP-Authentication, will be loaded as `ldap_config.py`.
      '';
    };

    secretKeyFile = mkOption {
      type = types.path;
      description = mdDoc ''
        Path to a file containing the secret key.
      '';
    };

    headscaleAPIKeyFile = mkOption {
      type = types.path;
      description = mdDoc ''
        Path to a file containing the Headscale API key.
      '';
    };

    probeRepoHost = mkOption {
      type = types.str;
      description = mdDoc ''
        Hostname of the GitLab containing the probe config repo.
        Used for ssh-keyscan on initial cloning.
      '';
    };

    probeRepoSSHCloneURL = mkOption {
      type = types.str;
      description = mdDoc ''
        Git SSH URL for the initial cloning of the probe config repo.
      '';
    };
    
    propeRepoSSHDeployPrivKeyFile = mkOption {
      type = types.path;
      description = mdDoc ''
        Path to a file containing the private key of the GitLab deploy key.
        This key needs read-write access to the repo as it is used to push updates.
      '';
    };

    propeRepoSSHDeployPubKeyFile = mkOption {
      type = types.path;
      description = mdDoc ''
        Path to a file containing the public key of the GitLab deploy key.
        This key needs read-write access to the repo as it is used to push updates.
      '';
    };

    probeRepoAccessTokenFile = mkOption {
      type = types.path;
      description = mdDoc ''
        Path to a file containing the GitLab access token for the probes config repo.
        This token is given to the probes. Please use a read-only token.
      '';
    };

    metricsApiKeyFile = mkOption {
      type = types.path;
      description = mdDoc ''
        Path to a file containing the API key for the metrics host to update the bearer
        tokens for the probes from SPARKY-Web. Use a long, auto generated password for this.
      '';
    };

    nginx = mkOption {
      type = types.submodule (
        recursiveUpdate
          (import (modulesPath + "/services/web-servers/nginx/vhost-options.nix") { inherit config lib; }) {}
      );
      default = { };
      example = literalExpression ''
        {
          # To enable encryption and let let's encrypt take care of certificate
          forceSSL = true;
          enableACME = true;
          # To set the SPARKY-Web virtualHost as the default virtualHost;
          default = true;
        }
      '';
      description = mdDoc ''
        With this option, you can customize the nginx virtualHost settings.
      '';
    };

    headscaleURL = mkOption {
      type = types.str;
      description = mdDoc ''
        URL of the headscale server.
      '';
    };

    probeRepoURL = mkOption {
      type = types.str;
      example = "https://gitlab.com/api/v4/projects/XXXXX/repository/";
      description = mdDoc ''
        URL of the GitLab API endpoint for the probe config repo.
      '';
    };

    probeNixOSStateVersion = mkOption {
      type = types.str;
      default = "23.05";
      description = mdDoc ''
        NixOS state version for the generated probe NixOS configurations.
      '';
    };

    probeSubnet = mkOption {
      type = types.str;
      description = mdDoc ''
        Subnet of the probes in the tailnet.
      '';
    };

    probeHostnamePrefix = mkOption {
      type = types.str;
      default = "probe";
      description = mdDoc ''
        Prefix for the hostnames of the probes (the text before the number of the probe).
      '';
    };

    extraConfig = mkOption {
      type = types.lines;
      default = "";
      description = mdDoc ''
        Additional lines of configuration appended to the `configuration.py`.
      '';
    };
  };

  config = mkIf cfg.enable {
    system.build.sparkyWebPkg = pkg;

    profiles.sparky-web.plugins = mkIf cfg.enableLdap (ps: [ ps.django-auth-ldap ]);

    services.postgresql = {
      enable = true;
      package = pkgs.postgresql_14;
      ensureDatabases = [ "sparky-web" ];
      ensureUsers = [
        {
          name = "sparky-web";
          ensureDBOwnership = true;
        }
      ];
    };

    environment.systemPackages = [ sparkyWebManageScript ];

    systemd.services.sparky-web-repo-setup = {
      description = "SPARKY Web probe config repo initialization";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      path = with pkgs; [ git openssh ];

      script = ''
        mkdir -p .ssh

        if [[ ! -s .ssh/known_hosts ]]; then
          ssh-keyscan ${cfg.probeRepoHost} > .ssh/known_hosts
        fi

        ln -sf ${cfg.propeRepoSSHDeployPrivKeyFile} .ssh/id_ed25519
        ln -sf ${cfg.propeRepoSSHDeployPubKeyFile} .ssh/id_ed25519.pub

        if [[ -d probe-repo ]]; then
          exit 0
        fi

        git clone ${cfg.probeRepoSSHCloneURL} probe-repo
      '';

      serviceConfig = {
        Type = "oneshot";
        WorkingDirectory = "/var/lib/sparky-web";
        User = "sparky-web";
        Group = "sparky-web";
        StateDirectory = "sparky-web";
        StateDirectoryMode = "0750";
        Restart = "on-failure";
      };
    };

    systemd.services.sparky-web = {
      description = "SPARKY Web";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" "sparky-web-repo-init.service" ];
      path = with pkgs; [ git openssh ];

      preStart = ''
        ${pkg}/bin/sparky-web migrate
      '';

      environment = {
        PYTHONPATH = pkg.pythonPath;
      };

      serviceConfig = {
        WorkingDirectory = "/var/lib/sparky-web";
        User = "sparky-web";
        Group = "sparky-web";
        StateDirectory = "sparky-web";
        StateDirectoryMode = "0750";
        Restart = "on-failure";
        ExecStart = ''
          ${pkg.python.pkgs.gunicorn}/bin/gunicorn sparky_web.wsgi \
            --workers 5 \
            --bind ${cfg.listenAddress}:${toString cfg.port} \
            --pythonpath ${pkg}/opt/sparky-web
        '';
      };
    };

    networking.firewall.allowedTCPPorts = [ 80 443 ];

    services.nginx = {
      enable = true;
      virtualHosts."${cfg.fqdn}" = mkMerge [
        cfg.nginx
        {
          locations."/" = {
            proxyPass = "http://${cfg.listenAddress}:${toString cfg.port}";
            extraConfig = ''
              uwsgi_param Host $host;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $http_x_forwarded_proto;
            '';
          };
          locations."/static/" = {
            alias = "${pkg}/opt/sparky-web/static/";
          };
        }
      ];
    };

    users.users.sparky-web = {
      home = "/var/lib/sparky-web";
      isSystemUser = true;
      group = "sparky-web";
    };
    users.groups.sparky-web = {};
  };
}