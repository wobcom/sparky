{ config, lib, pkgs, ... }:

with lib;

let cfg = config.profiles.tailnet;
in {
  options.profiles.tailnet = {
    enable = mkEnableOption (mdDoc "Enable the SPARKY tailnet profile");

    ip = mkOption {
      type = types.str;
      description = mdDoc ''
        IP in the tailnet.
      '';
    };

    preAuthKey = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = mdDoc ''
        Headscale PreAuthKey for first login to the tailnet. Only used for ZTP.
        Make sure to use a non-reusable key with a short expiration time.
      '';
    };

    headscaleFQDN = mkOption {
      type = types.str;
      description = mdDoc ''
        FQDN of the headscale server.
      '';
    };
  };

  config = mkIf cfg.enable {
    systemd.network = {
        enable = true;
        networks = {
          "20-lo" = {
            name = "lo";
            address = [
              "${cfg.ip}/128" 
            ];
          };
        };
      };

    systemd.services.tailscale-setup = {
      description = "Tailscale initial setup and connect at startup";
      after = [ "tailscaled.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        ${pkgs.tailscale}/bin/tailscale up --login-server https://${cfg.headscaleFQDN} --advertise-routes ${cfg.ip}/128 --accept-routes ${optionalString (cfg.preAuthKey != null) "--auth-key ${cfg.preAuthKey}"}
      '';
    };

    services.tailscale.enable = true;
  };
}