{ config, lib, pkgs, ... }:

with lib;

let cfg = config.profiles.sparky-tailnet;
in {
  options.profiles.sparky-tailnet = {
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

    headscaleURL = mkOption {
      type = types.str;
      description = mdDoc ''
        URL of the headscale server.
      '';
    };
  };

  config = mkIf cfg.enable {
    systemd.network = {
      enable = true;
      config = {
        networkConfig.ManageForeignRoutes = false;
      };
      networks = {
        "20-tailscale0" = {
          name = "tailscale0";
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
        ${pkgs.tailscale}/bin/tailscale up --login-server ${cfg.headscaleURL} --advertise-routes ${cfg.ip}/128 --accept-routes ${optionalString (cfg.preAuthKey != null) "--auth-key ${cfg.preAuthKey}"}
      '';
    };

    services.tailscale.enable = true;
  };
}
