{ config, lib, pkgs, nodes, ... }:

with lib;

let cfg = config.profiles.ztp-image;
in {
  options.profiles.ztp-image = {
    enable = mkEnableOption (mdDoc "Enable the SPARKY ZTP image profile");

    webURL = mkOption {
      type = types.str;
      description = mdDoc ''
        URL of the SPARKY-Web server. Must not have a tailing slash.
      '';
    };
  };

  config = mkIf cfg.enable {
    # grow partition at boot
    boot.growPartition = true;

    # image build stuff
    system.build.raw = import "${toString modulesPath}/../lib/make-disk-image.nix" {
      inherit lib config pkgs;
      diskSize = "auto";
      format = "raw";
      bootSize = "512M";
      partitionTableType = "efi";
    };

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

    # setup service
    systemd.services.sparky-setup = {
      description = "SPARKY Probe Setup";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      restartIfChanged = false;
      path = with pkgs; [ jq curl gnutar nixos-rebuild gzip ];
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

        INTERFACE_NAME=$(ls /sys/class/net/ | grep enp | tr -d '\n')
        MAC_ADDRESS=$(cat /sys/class/net/$INTERFACE_NAME/address | tr -d '\n')

        PROBE_INIT_JSON=$(curl -X POST -F mac=$MAC_ADDRESS ${cfg.webURL}/api/v1/probe-init)
        API_KEY=$(echo $PROBE_INIT_JSON | jq -r '.data."api-key"' | tr -d '\n')
        HOSTNAME=$(echo $PROBE_INIT_JSON | jq -r .data.hostname | tr -d '\n')
        REPO_BASE_URL=$(echo $PROBE_INIT_JSON | jq -r '.data."repo-url"' | tr -d '\n')
        REPO_ACCESS_TOKEN=$(echo $PROBE_INIT_JSON | jq -r '.data."access-token"' | tr -d '\n')

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
