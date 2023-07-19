{ config, lib, pkgs, nodes, ... }:

with lib;

let cfg = config.profiles.probe;
in {
  options.profiles.probe = {
    enable = mkEnableOption (mdDoc "Enable the SPARKY probe profile");

    ip = mkOption {
      type = types.str;
      description = mdDoc ''
        IP of the probe in the tailnet.
      '';
    };

    preAuthKey = mkOption {
      type = types.str;
      description = mdDoc ''
        Headscale PreAuthKey for first login to the tailnet.
        Make sure to use a non-reusable key with a short expiration time.
      '';
    };

    prometheusIP = mkOption {
      type = types.str;
      description = mdDoc ''
        IP of the prometheus server in the tailnet.
      '';
    };

    headscaleIP = mkOption {
      type = types.str;
      description = mdDoc ''
        IP of the headscale server in the tailnet.
      '';
    };

    iperf3 = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = mdDoc ''
          Enable iperf3 tests from this probe.
        '';
      };
      bandwidthLimit = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = mdDoc ''
          Bandwidth limit of the iperf3 tests.
        '';
      };
      target = mkOption {
        type = types.str;
        default = "speedtest.wobcom.de";
        description = mdDoc ''
          Target server of the iperf3 tests.
        '';
      };
      targetPort = mkOption {
        type = types.port;
        default = 6201;
        description = mdDoc ''
          Target port of the iperf3 tests.
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    boot.loader.systemd-boot.enable = true;
    # Copy the systemd-boot loader to the position of the windows boot loader,
    # because for some reason some S920 ThinClients (with the same BIOS version
    # and factory defaults!) find the bootloader in /boot/EFI/BOOT/BOOTX64.EFI
    # and some don't find it there, but they find a windows boot loader and
    # so we copy the systemd-boot loader to the position of the windows boot
    # loader as a fallback.
    boot.loader.systemd-boot.extraInstallCommands = ''
      mkdir -p /boot/EFI/Microsoft/Boot
      cp /boot/EFI/BOOT/BOOTX64.EFI /boot/EFI/Microsoft/Boot/bootmgfw.efi
    '';

    boot.kernelParams = [
      "console=ttyS0,115200"
      "console=tty1"
    ];

    # Limit SSH to tailnet IP
    services.openssh.openFirewall = mkForce false;

    networking.firewall.extraInputRules = (''
      ip6 daddr ${cfg.ip} ip6 saddr ${cfg.headscaleIP} tcp dport 22 accept comment "SSH from headscale"
      ip6 daddr ${cfg.ip} ip6 saddr ${cfg.prometheusIP} tcp dport ${toString config.services.prometheus.exporters.node.port} accept comment "Node Exporter"
      ip6 daddr ${cfg.ip} ip6 saddr ${cfg.prometheusIP} tcp dport ${toString config.services.prometheus.exporters.smokeping.port} accept comment "Smokeping Exporter"
    '' + optionalString cfg.iperf3.enable ''
      ip6 daddr ${cfg.ip} ip6 saddr ${cfg.prometheusIP} tcp dport ${toString config.services.prometheus-local.exporters.iperf3.port} accept comment "iperf3 Exporter"
    '');

    networking.useDHCP = true;

    networking.nftables.enable = true;

    profiles.tailnet = {
      enable = true;
      ip = cfg.ip;
      preAuthKey = cfg.preAuthKey;
    };

    # Prometheus
    services.prometheus.exporters.node = {
      enable = true;
      listenAddress = "[${cfg.ip}]";
      port = 9100;
    };
    services.prometheus-local.exporters.iperf3 = mkIf cfg.iperf3.enable {
      enable = true;
      listenAddress = "[${cfg.ip}]";
      port = 9579;
      extraFlags = [
        "-iperf3.path ${pkgs.iperf3d}/bin/iperf3d"
        "-iperf3.port ${toString cfg.iperf3.targetPort}"
        "-iperf3.time 15s"
        "-iperf3.reverse"
      ] ++ optional (cfg.iperf3.bandwidthLimit != null) "-iperf3.bandwidth ${toString cfg.iperf3.bandwidthLimit}";
    };
    systemd.services.prometheus-iperf3-exporter.environment = mkIf cfg.iperf3.enable {
      "IPERF3D_IPERF3_PATH" = "${pkgs.iperf3}/bin/iperf3";
    };
    services.prometheus.exporters.smokeping = {
      enable = true;
      listenAddress = "[${cfg.ip}]";
      port = 9374;
      hosts = [
        "a400.speedtest.wobcom.de"
        "a209.speedtest.wobcom.de"
        "a210.speedtest.wobcom.de"
      ];
    };
    # Wait for DNS after boot, then wait additional 10 seconds to make sure smokeping is ready
    systemd.services.prometheus-smokeping-exporter.after = [ "smokeping-ready.service" ];
    
    systemd.services.smokeping-ready = {
      description = "Helper service to delay smokeping start after boot";
      after = [ "network-online.target" "nss-lookup.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        DynamicUser = true;
        RemainAfterExit = true;
      };
      script = ''
        until ${pkgs.host}/bin/host wobcom.de; do sleep 1; done
        sleep 10
      '';
    };
  };
}
