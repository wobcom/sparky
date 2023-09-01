{ config, lib, pkgs, nodes, modulesPath, ... }:

with lib;

let cfg = config.profiles.sparky-ztp-image;
in {
  options.profiles.sparky-ztp-image = {
    enable = mkEnableOption (mdDoc "Enable the SPARKY ZTP image profile");

    webURL = mkOption {
      type = types.str;
      description = mdDoc ''
        URL of the SPARKY-Web server. Must not have a tailing slash.
      '';
    };

    macInterfaceName = mkOption {
      type = types.str;
      description = mdDoc ''
        Name of the interface from which the MAC address is to be used for the ZTP.
        If `sdMac` is enabled, the MAC address of this interface will be set to the generated MAC.
      '';
    };

    sdMac = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = mdDoc ''
          Use the CID of the SD-Card for generating a unique and persistend MAC address (also used for ZTP).
          Useful for devices that don't have a unique MAC address like the NanoPi R2S.
        '';
      };
      macPrefix = mkOption {
        type = types.str;
        default = "aa:91:36";
        description = mdDoc ''
          Prefix (OUI) of the generated MAC addresses.
        '';
      };
      blockDeviceName = mkOption {
        type = types.str;
        default = "mmcblk0";
        description = mdDoc ''
          Name of the block device of the SD-Card (on the device that will be the probe later).
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
          {
            command = "${pkgs.systemd}/bin/reboot";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];

    # SD-MAC setup
    systemd.services.sdmac-setup = mkIf cfg.sdMac.enable {
      description = "SD-MAC Setup";
      wantedBy = [ "multi-user.target" ];
      before = [ "network.target" ];
      path = with pkgs; [ iproute2 gnused gawk ];
      serviceConfig = {
        Restart = "on-failure";
        RestartSec = 2;
        Type = "oneshot";
        WorkingDirectory = "/var/lib/sparky";
        User = "sparky";
        Group = "sparky";
      };
      script = ''
        set -euo pipefail

        MAC_SUFFIX=$(cat /sys/block/${cfg.sdMac.blockDeviceName}/device/cid | md5sum | awk '{ print $1 }' | head -c 6 | sed -e 's/./&:/2' -e 's/./&:/5' | tr -d '\n')
        MAC_ADDRESS="${cfg.sdMac.macPrefix}:$MAC_SUFFIX"

        ip link set dev ${cfg.macInterfaceName} down
        ip link set dev ${cfg.macInterfaceName} address $MAC_ADDRESS
        ip link set dev ${cfg.macInterfaceName} up
      '';
    };

    # setup service
    systemd.services.sparky-setup = {
      description = "SPARKY Probe Setup";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      restartIfChanged = false;
      path = with pkgs; [ jq curl gnutar nixos-rebuild gzip gawk gnused ];
      serviceConfig = {
        Restart = "on-failure";
        RestartSec = 2;
        Type = "oneshot";
        WorkingDirectory = "/var/lib/sparky";
        User = "sparky";
        Group = "sparky";
      };
      script = ''
        set -euo pipefail

        ${optionalString (!cfg.sdMac.enable) ''
          MAC_ADDRESS=$(cat /sys/class/net/${cfg.macInterfaceName}/address | tr -d '\n')
        ''}

        ${optionalString (cfg.sdMac.enable) ''
          MAC_SUFFIX=$(cat /sys/block/${cfg.sdMac.blockDeviceName}/device/cid | md5sum | awk '{ print $1 }' | head -c 6 | sed -e 's/./&:/2' -e 's/./&:/5' | tr -d '\n')
          MAC_ADDRESS="${cfg.sdMac.macPrefix}:$MAC_SUFFIX"
        ''}

        PROBE_INIT_JSON=$(curl -X POST -F mac=$MAC_ADDRESS ${cfg.webURL}/api/v1/probe-init)
        API_KEY=$(echo $PROBE_INIT_JSON | jq -r '.data."api-key"' | tr -d '\n')
        HOSTNAME=$(echo $PROBE_INIT_JSON | jq -r .data.hostname | tr -d '\n')
        METRICS_BEARER=$(echo $PROBE_INIT_JSON | jq -r '.data."metrics-bearer"' | tr -d '\n')

        REPO_BASE_URL=$(echo $PROBE_INIT_JSON | jq -r '.data."repo-url"' | tr -d '\n')
        REPO_ACCESS_TOKEN=$(echo $PROBE_INIT_JSON | jq -r '.data."access-token"' | tr -d '\n')

        echo $METRICS_BEARER > /var/lib/sparky/metrics_bearer
        echo $API_KEY > /var/lib/sparky/api_key

        REPO_BRANCH_URL=''${REPO_BASE_URL}/branches/main?private_token=''${REPO_ACCESS_TOKEN}
        REPO_ARCHIVE_URL=''${REPO_BASE_URL}/archive.tar.gz?private_token=''${REPO_ACCESS_TOKEN}

        # get current commit
        CURRENT_COMMIT=$(curl $REPO_BRANCH_URL | jq -r .commit.id | tr -d '\n')

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

        # generate boot config
        sudo nixos-rebuild boot --flake .#''${HOSTNAME}

        # reboot
        sudo reboot
      '';
    };
  };
}
