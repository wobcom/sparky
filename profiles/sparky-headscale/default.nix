{ config, lib, pkgs, ... }:

with lib;

let cfg = config.profiles.sparky-headscale;
in {
  options.profiles.sparky-headscale = {
    enable = mkEnableOption (mdDoc "Enable the SPARKY headscale profile. Requires a configured tailnet on the host.");

    probeSubnet = mkOption {
      type = types.str;
      description = mdDoc ''
        Subnet of the probes in the tailnet.
      '';
    };

    metricsIP = mkOption {
      type = types.str;
      description = mdDoc ''
        IP of the metrics server in the tailnet.
      '';
    };

    fqdn = mkOption {
      type = types.str;
      description = mdDoc ''
        The FQDN for the nginx vHost of the headscale server.
      '';
    };

    derp = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = mdDoc ''
          Enable a local DERP server.
        '';
      };

      regionID = mkOption {
        type = types.str;
        description = mdDoc ''
          Region ID for the local DERP server.
        '';
      };

      regionCode = mkOption {
        type = types.str;
        description = mdDoc ''
          Region code for the local DERP server.
        '';
      };

      regionName = mkOption {
        type = types.str;
        description = mdDoc ''
          Region name for the local DERP server.
        '';
      };
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
          # To set the SPARKY headscale virtualHost as the default virtualHost;
          default = true;
        }
      '';
      description = mdDoc ''
        With this option, you can customize the nginx virtualHost settings.
      '';
    };
  };

  config = mkIf cfg.enable {
    services.headscale = {
      enable = true;
      address = "127.0.0.1";
      port = 8080;
      settings = {
        server_url = "https://${cfg.fqdn}";
        dns_config.nameservers = [ "1.1.1.1" "1.0.0.1" ];
        db_port = 5432;
        ip_prefixes = [ "100.64.0.0/10" ]; # use default headscale prefix
        acl_policy_path = let
          headscaleIP = config.profiles.sparky-tailnet.ip;
          
          isProd = any (x: x == "prod") config.deployment.tags;
        in pkgs.writeText "headscale-acl" (builtins.toJSON {
          hosts = {
            "host:headscale" = "${headscaleIP}/128";
            "host:metrics" = "${cfg.metricsIP}/128";
            "host:probes" = "${cfg.probeSubnet}";
          };
          acls = [
            {
              # Allow SSH Headscale --> Probes
              action = "accept";
              proto = "tcp";
              src = [ "host:headscale" ];
              dst = [ "host:probes:22" ];
            }
            {
              # Allow ICMPv6
              action = "accept";
              proto = "58"; # ICMPv6
              src = [ "*" ];
              dst = [ "*:*" ];
            }
            {
              # Allow VM remote_write Probes --> Metrics
              action = "accept";
              proto = "tcp";
              src = [ "host:probes" ];
              dst = [ "host:metrics:80" ];
            }
          ];
        });
        derp.server = mkIf cfg.derp.enable {
          enabled = cfg.derp.enable;
          region_id = cfg.derp.regionID;
          region_code = cfg.derp.regionCode;
          region_name = cfg.derp.regionName;
          stun_listen_addr = "0.0.0.0:3478";
        };
      };
    };

    environment.systemPackages = with pkgs; [ headscale ];
    
    networking.firewall.allowedTCPPorts = [ 80 443 ];
    networking.firewall.allowedUDPPorts = mkIf cfg.derp.enable [ 3478 ];

    services.nginx = {
      enable = true;
      virtualHosts."${cfg.fqdn}" = mkMerge [
        cfg.nginx
        {
          locations."/" = {
            proxyPass = "http://${config.services.headscale.address}:${toString config.services.headscale.port}";
            proxyWebsockets = true;
            extraConfig = ''
              proxy_set_header Host $host;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $remote_addr;
            '';
          };
        }
      ];
    };
  };
}
