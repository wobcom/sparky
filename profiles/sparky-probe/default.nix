{ config, lib, pkgs, nodes, ... }:

with lib;

let cfg = config.profiles.sparky-probe;
in {
  options.profiles.sparky-probe = {
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

    metricsIP = mkOption {
      type = types.str;
      description = mdDoc ''
        IP of the metrics server in the tailnet.
      '';
    };

    headscaleIP = mkOption {
      type = types.str;
      description = mdDoc ''
        IP of the headscale server in the tailnet.
      '';
    };

    webURL = mkOption {
      type = types.str;
      description = mdDoc ''
        URL of the SPARKY-Web server. Must not have a tailing slash.
      '';
    };

    blackbox = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = mdDoc ''
          Enable blackbox tests from this probe.
        '';
      };
      httpTargets = mkOption {
        type = types.listOf types.str;
        description = mdDoc ''
          Targets for the blackbox HTTP tests tests.
        '';
        default = [
          "https://apple.com"
          "https://google.com"
          "https://wikipedia.com"
          "https://youtube.com"
        ];
      };
    };

    traceroute = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = mdDoc ''
          Enable traceroute tests from this probe.
        '';
      };
      targets = mkOption {
        type = types.listOf types.str;
        description = mdDoc ''
          Targets for the traceroute tests.
        '';
        default = [
          "a400.speedtest.wobcom.de"
          "a209.speedtest.wobcom.de"
          "a210.speedtest.wobcom.de"
        ];
      };
    };

    smokeping = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = mdDoc ''
          Enable smokeping tests from this probe.
        '';
      };
      targets = mkOption {
        type = types.listOf types.str;
        description = mdDoc ''
          Targets for the smokeping tests.
        '';
        default = [
          "a400.speedtest.wobcom.de"
          "a209.speedtest.wobcom.de"
          "a210.speedtest.wobcom.de"
        ];
      };
      onlineCheckTarget = mkOption {
        type = types.str;
        default = "wobcom.de";
        description = mdDoc ''
          Target for checking if DNS resolution works.
        '';
      };
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
    # system user
    users.users.sparky = {
      isSystemUser = true;
      home = "/var/lib/sparky";
      group = "sparky";
    };

    users.groups.sparky = {};

    # state directory and files
    systemd.tmpfiles.rules = [
      "d /var/lib/sparky                             0750 sparky sparky - -"
      "f /var/lib/sparky/config_repo_rev             0600 sparky sparky - -"
      "f /var/lib/sparky/api_key                     0600 sparky sparky - -"
      "f /var/lib/sparky/metrics_bearer              0600 sparky sparky - -"
      "d /var/lib/sparky/config                      0700 sparky sparky - -"
      "d /var/lib/sparky/config_download             0700 sparky sparky - -"
    ];

    # allow sparky system user "sudo nixos-rebuild"
    security.sudo.extraRules = [
      {
        users = [ "sparky" ];
        commands = [
          {
            command = "${pkgs.nixos-rebuild}/bin/nixos-rebuild";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];

    # update service timer
    systemd.timers.sparky-update = {
      description = "SPARKY NixOS Update";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*:0/15"; # every 15 minutes
        AccuracySec = "1second";
      };
    };

    # update service
    systemd.services.sparky-update = {
      description = "SPARKY NixOS Update";
      # could trigger a restart loop and the service gets started
      # by a timer, so it does not matter
      restartIfChanged = false;
      path = with pkgs; [ jq curl gnutar nixos-rebuild gzip ];
      serviceConfig = {
        Type = "oneshot";
        WorkingDirectory = "/var/lib/sparky";
        User = "sparky";
        Group = "sparky";
      };
      script = ''
        set -euo pipefail

        API_KEY=$(cat /var/lib/sparky/api_key | tr -d '\n')
        CONFIG_JSON=$(curl -X POST -F api-key=$API_KEY ${cfg.webURL}/api/v1/probe-update)
        HOSTNAME=$(echo $CONFIG_JSON | jq -r .data.hostname | tr -d '\n')
        REPO_BASE_URL=$(echo $CONFIG_JSON | jq -r '.data."repo-url"' | tr -d '\n')
        REPO_ACCESS_TOKEN=$(echo $CONFIG_JSON | jq -r '.data."access-token"' | tr -d '\n')
        METRICS_BEARER=$(echo $CONFIG_JSON | jq -r '.data."metrics-bearer"' | tr -d '\n')

        REPO_BRANCH_URL=''${REPO_BASE_URL}/branches/main?private_token=''${REPO_ACCESS_TOKEN}
        REPO_ARCHIVE_URL=''${REPO_BASE_URL}/archive.tar.gz?private_token=''${REPO_ACCESS_TOKEN}

        # save metrics bearer
        echo $METRICS_BEARER > /var/lib/sparky/metrics_bearer

        # get current commit
        CURRENT_COMMIT=$(curl $REPO_BRANCH_URL | jq -r .commit.id | tr -d '\n')
        LATEST_KNOWN_COMMIT=$(cat /var/lib/sparky/config_repo_rev | tr -d '\n')

        if [[ $CURRENT_COMMIT == $LATEST_KNOWN_COMMIT ]]; then
          # we are up2date
          exit 0
        fi

        # save current commit
        echo $CURRENT_COMMIT > /var/lib/sparky/config_repo_rev

        # clear download dir
        rm -rf /var/lib/sparky/config_download/*

        # download latest version
        curl $REPO_ARCHIVE_URL > /var/lib/sparky/config_download/archive.tar.gz

        # clear config dir
        rm -rf /var/lib/sparky/config/*

        # unpack new config
        cd /var/lib/sparky/config
        tar xvf /var/lib/sparky/config_download/archive.tar.gz --strip-components=1

        # nixos-rebuild needs sudo in its path
        export PATH=/run/wrappers/bin:$PATH

        # apply new config
        sudo nixos-rebuild switch --flake .#''${HOSTNAME}
      '';
    };

    # Limit SSH to tailnet IP
    services.openssh.openFirewall = mkForce false;

    # Firewall limitations to tailnet IPs
    networking.firewall.extraInputRules = (''
      ip6 daddr ${cfg.ip} ip6 saddr ${cfg.headscaleIP} tcp dport 22 accept comment "SSH from headscale"
    '');

    # we need nftables for our firewall rules above
    networking.nftables.enable = true;

    # the probes get their IPs over DHCP
    networking.useDHCP = true;

    # configure tailnet
    profiles.sparky-tailnet = {
      enable = true;
      ip = cfg.ip;
      preAuthKey = cfg.preAuthKey;
    };

    # vmagent, module from unstable / 23.11 is required here
    services.vmagent = {
      enable = true;
      package = pkgs.victoriametrics;
      remoteWriteUrl = "http://[${cfg.metricsIP}]/remote_write";
      extraArgs = [ "-remoteWrite.bearerTokenFile=/run/vmagent/bearer_token" "-enableTCP6" ];
      prometheusConfig = {
        scrape_configs = [
          {
            job_name = "node";
            scrape_interval = "30s";
            scrape_timeout = "29s";
            metrics_path = "/metrics";
            honor_labels = false;
            honor_timestamps = true;
            scheme = "http";
            static_configs = [
              {
                targets = [ "127.0.0.1:9100" ];
              }
            ];
          }
        ] ++ (optionals cfg.blackbox.enable [
          {
            job_name = "blackbox-http-v4";
            scrape_interval = "30s";
            scrape_timeout = "29s";
            metrics_path = "/probe";
            honor_labels = false;
            honor_timestamps = true;
            scheme = "http";
            params = {
              module = [ "http_2xx_v4" ];
            };
            static_configs = [
              {
                targets = cfg.blackbox.httpTargets;
              }
            ];
            relabel_configs = [
              {
                source_labels = [ "__address__" ];
                target_label = "__param_target";
              }
              {
                source_labels = [ "__param_target" ];
                target_label = "target";
              }
              {
                replacement = "127.0.0.1:9115";
                target_label = "__address__";
              }
            ];
          }
          {
            job_name = "blackbox-http-v6";
            scrape_interval = "30s";
            scrape_timeout = "29s";
            metrics_path = "/probe";
            honor_labels = false;
            honor_timestamps = true;
            scheme = "http";
            params = {
              module = [ "http_2xx_v6" ];
            };
            static_configs = [
              {
                targets = cfg.blackbox.httpTargets;
              }
            ];
            relabel_configs = [
              {
                source_labels = [ "__address__" ];
                target_label = "__param_target";
              }
              {
                source_labels = [ "__param_target" ];
                target_label = "target";
              }
              {
                replacement = "127.0.0.1:9115";
                target_label = "__address__";
              }
            ];
          }
        ]) ++ (optional cfg.smokeping.enable {
          job_name = "smokeping";
          scrape_interval = "30s";
          scrape_timeout = "29s";
          metrics_path = "/metrics";
          honor_labels = false;
          honor_timestamps = true;
          scheme = "http";
          static_configs = [
            {
              targets = [ "127.0.0.1:9374" ];
            }
          ];
        }) ++ (optional cfg.iperf3.enable {
          job_name = "iperf3";
          scrape_interval = "2m";
          scrape_timeout = "30s";
          metrics_path = "/probe";
          honor_labels = false;
          honor_timestamps = true;
          scheme = "http";
          static_configs = [
            {
              targets = [ cfg.iperf3.target ];
            }
          ];
          relabel_configs = [
            {
              source_labels = [ "__address__" ];
              target_label = "__param_target";
            }
            {
              replacement = "127.0.0.1:9579";
              target_label = "__address__";
            }
          ];
        });
      };
    };

    systemd.services.vmagent.serviceConfig = {
      # define runtime dir
      RuntimeDirectory = "vmagent";
      RuntimeDirectoryMode = "0750";
      # copy bearer token to runtime dir before start (as root)
      ExecStartPre = [ "!${pkgs.writeShellScript "vmagent-bearer-setup" ''
        set -euo pipefail
        cp /var/lib/sparky/metrics_bearer /run/vmagent/bearer_token
        chown vmagent:vmagent /run/vmagent/bearer_token
        chmod 640 /run/vmagent/bearer_token
      ''}"];
    };

    # used by telegraf
    programs.mtr.enable = cfg.traceroute.enable;

    # telegraf, exports to local vmagent
    services.telegraf = mkIf cfg.traceroute.enable {
      enable = true;
      extraConfig = {
        inputs = {
          exec = (map (target: {
            commands = [ "${pkgs.mtr}/bin/mtr -4 -C -n ${target}" ]; 
            csv_column_names = [ "" "" "status" "dest" "hop" "ip" "loss" "snt" "" "" "avg" "best" "worst" "stdev" ];
            csv_skip_rows = 1;
            csv_tag_columns = [ "dest" "hop" "ip" ];
            data_format = "csv";
            name_override = "mtr_v4";
            timeout = "40s";
            interval = "30s";
          }) cfg.traceroute.targets) ++ (map (target: {
            commands = [ "${pkgs.mtr}/bin/mtr -6 -C -n ${target}" ]; 
            csv_column_names = [ "" "" "status" "dest" "hop" "ip" "loss" "snt" "" "" "avg" "best" "worst" "stdev" ];
            csv_skip_rows = 1;
            csv_tag_columns = [ "dest" "hop" "ip" ];
            data_format = "csv";
            name_override = "mtr_v6";
            timeout = "40s";
            interval = "30s";
          }) cfg.traceroute.targets);
        };
        outputs = {
          influxdb = {
            database = "telegraf";
            urls = [ "http://127.0.0.1:8429" ];
          };
        };
      };
    };

    # Prometheus, scraped by local vmagent
    services.prometheus.exporters.node = {
      enable = true;
      listenAddress = "127.0.0.1";
      port = 9100;
    };
    services.prometheus.exporters.blackbox = mkIf cfg.blackbox.enable {
      enable = true;
      listenAddress = "127.0.0.1";
      port = 9115;
      configFile = pkgs.writeText "blackbox-exporter-config" (builtins.toJSON {
        modules = {
          http_2xx_v4 = {
            prober = "http";
            timeout = "5s";
            http = {
              method = "GET";
              ip_protocol_fallback = false;
              no_follow_redirects = false;
              preferred_ip_protocol = "ip4";
            };
          };
          http_2xx_v6 = {
            prober = "http";
            timeout = "5s";
            http = {
              method = "GET";
              ip_protocol_fallback = false;
              no_follow_redirects = false;
              preferred_ip_protocol = "ip6";
            };
          };
        };
      });
    };
    services.prometheus-local.exporters.iperf3 = mkIf cfg.iperf3.enable {
      enable = true;
      listenAddress = "127.0.0.1";
      port = 9579;
      extraFlags = [
        "-iperf3.path ${pkgs.iperf3d}/bin/iperf3d" # requires iperf3d from unstable / 23.11
        "-iperf3.port ${toString cfg.iperf3.targetPort}"
        "-iperf3.time 15s"
        "-iperf3.reverse"
      ] ++ optional (cfg.iperf3.bandwidthLimit != null) "-iperf3.bandwidth ${toString cfg.iperf3.bandwidthLimit}";
    };
    systemd.services.prometheus-iperf3-exporter.environment = mkIf cfg.iperf3.enable {
      "IPERF3D_IPERF3_PATH" = "${pkgs.iperf3}/bin/iperf3";
    };
    services.prometheus.exporters.smokeping = mkIf cfg.smokeping.enable {
      enable = true;
      listenAddress = "127.0.0.1";
      port = 9374;
      hosts = cfg.smokeping.targets;
    };
    # Wait for DNS after boot, then wait additional 10 seconds to make sure smokeping is ready
    systemd.services.prometheus-smokeping-exporter.after = mkIf cfg.smokeping.enable [ "smokeping-ready.service" ];

    systemd.services.smokeping-ready = mkIf cfg.smokeping.enable {
      description = "Helper service to delay smokeping start after boot";
      after = [ "network-online.target" "nss-lookup.target" ]
        ++ optionals config.profiles.sparky-sd-mac.enable [ "sdmac-setup.service" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        DynamicUser = true;
        RemainAfterExit = true;
      };
      script = ''
        until ${pkgs.host}/bin/host ${cfg.smokeping.onlineCheckTarget}; do sleep 1; done
        sleep 10
      '';
    };
  };
}
