{ config, pkgs, lib, options, modulesPath, ... }:

let
  inherit (lib) concatStrings foldl foldl' genAttrs literalExpression maintainers
                mapAttrsToList mkDefault mkEnableOption mkIf mkMerge mkOption
                optional types mkOptionDefault flip attrNames;

  cfg = config.services.prometheus-local.exporters;

  # each attribute in `exporterOpts` is expected to have specified:
  #   - port        (types.int):   port on which the exporter listens
  #   - serviceOpts (types.attrs): config that is merged with the
  #                                default definition of the exporter's
  #                                systemd service
  #   - extraOpts   (types.attrs): extra configuration options to
  #                                configure the exporter with, which
  #                                are appended to the default options
  #
  #  Note that `extraOpts` is optional, but a script for the exporter's
  #  systemd service must be provided by specifying either
  #  `serviceOpts.script` or `serviceOpts.serviceConfig.ExecStart`

  exporterOpts = genAttrs [
    "iperf3"
  ] (name:
    import (./. + "/${name}.nix") { inherit config lib pkgs options; }
  );

  mkExporterOpts = ({ name, port }: {
    enable = mkEnableOption (lib.mdDoc "the prometheus ${name} exporter");
    port = mkOption {
      type = types.port;
      default = port;
      description = lib.mdDoc ''
        Port to listen on.
      '';
    };
    listenAddress = mkOption {
      type = types.str;
      default = "0.0.0.0";
      description = lib.mdDoc ''
        Address to listen on.
      '';
    };
    extraFlags = mkOption {
      type = types.listOf types.str;
      default = [];
      description = lib.mdDoc ''
        Extra commandline options to pass to the ${name} exporter.
      '';
    };
    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = lib.mdDoc ''
        Open port in firewall for incoming connections.
      '';
    };
    firewallFilter = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = literalExpression ''
        "-i eth0 -p tcp -m tcp --dport ${toString port}"
      '';
      description = lib.mdDoc ''
        Specify a filter for iptables to use when
        {option}`services.prometheus.exporters.${name}.openFirewall`
        is true. It is used as `ip46tables -I nixos-fw firewallFilter -j nixos-fw-accept`.
      '';
    };
    user = mkOption {
      type = types.str;
      default = "${name}-exporter";
      description = lib.mdDoc ''
        User name under which the ${name} exporter shall be run.
      '';
    };
    group = mkOption {
      type = types.str;
      default = "${name}-exporter";
      description = lib.mdDoc ''
        Group under which the ${name} exporter shall be run.
      '';
    };
  });

  mkSubModule = { name, port, extraOpts, imports }: {
    ${name} = mkOption {
      type = types.submodule [{
        inherit imports;
        options = (mkExporterOpts {
          inherit name port;
        } // extraOpts);
      } ({ config, ... }: mkIf config.openFirewall {
        firewallFilter = mkDefault "-p tcp -m tcp --dport ${toString config.port}";
      })];
      internal = true;
      default = {};
    };
  };

  mkSubModules = (foldl' (a: b: a//b) {}
    (mapAttrsToList (name: opts: mkSubModule {
      inherit name;
      inherit (opts) port;
      extraOpts = opts.extraOpts or {};
      imports = opts.imports or [];
    }) exporterOpts)
  );

  mkExporterConf = { name, conf, serviceOpts }:
    let
      enableDynamicUser = serviceOpts.serviceConfig.DynamicUser or true;
    in
    mkIf conf.enable {
      warnings = conf.warnings or [];
      users.users."${name}-exporter" = (mkIf (conf.user == "${name}-exporter" && !enableDynamicUser) {
        description = "Prometheus ${name} exporter service user";
        isSystemUser = true;
        inherit (conf) group;
      });
      users.groups = (mkIf (conf.group == "${name}-exporter" && !enableDynamicUser) {
        "${name}-exporter" = {};
      });
      networking.firewall.extraCommands = mkIf conf.openFirewall (concatStrings [
        "ip46tables -A nixos-fw ${conf.firewallFilter} "
        "-m comment --comment ${name}-exporter -j nixos-fw-accept"
      ]);
      systemd.services."prometheus-${name}-exporter" = mkMerge ([{
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        serviceConfig.Restart = mkDefault "always";
        serviceConfig.PrivateTmp = mkDefault true;
        serviceConfig.WorkingDirectory = mkDefault /tmp;
        serviceConfig.DynamicUser = mkDefault enableDynamicUser;
        serviceConfig.User = mkDefault conf.user;
        serviceConfig.Group = conf.group;
        # Hardening
        serviceConfig.CapabilityBoundingSet = mkDefault [ "" ];
        serviceConfig.DeviceAllow = [ "" ];
        serviceConfig.LockPersonality = true;
        serviceConfig.MemoryDenyWriteExecute = true;
        serviceConfig.NoNewPrivileges = true;
        serviceConfig.PrivateDevices = mkDefault true;
        serviceConfig.ProtectClock = mkDefault true;
        serviceConfig.ProtectControlGroups = true;
        serviceConfig.ProtectHome = true;
        serviceConfig.ProtectHostname = true;
        serviceConfig.ProtectKernelLogs = true;
        serviceConfig.ProtectKernelModules = true;
        serviceConfig.ProtectKernelTunables = true;
        serviceConfig.ProtectSystem = mkDefault "strict";
        serviceConfig.RemoveIPC = true;
        serviceConfig.RestrictAddressFamilies = [ "AF_INET" "AF_INET6" ];
        serviceConfig.RestrictNamespaces = true;
        serviceConfig.RestrictRealtime = true;
        serviceConfig.RestrictSUIDSGID = true;
        serviceConfig.SystemCallArchitectures = "native";
        serviceConfig.UMask = "0077";
      } serviceOpts ]);
  };
in
{

  options.services.prometheus-local.exporters = mkOption {
    type = types.submodule {
      options = (mkSubModules);
      imports = [
      ];
    };
    description = lib.mdDoc "Prometheus exporter configuration";
    default = {};
    example = literalExpression ''
      {
        node = {
          enable = true;
          enabledCollectors = [ "systemd" ];
        };
        varnish.enable = true;
      }
    '';
  };

  config = mkMerge (
    mapAttrsToList (name: conf:
    mkExporterConf {
      inherit name;
      inherit (conf) serviceOpts;
      conf = cfg.${name};
    }) exporterOpts
  );
    
}
