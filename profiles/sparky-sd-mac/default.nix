{ config, lib, pkgs, ... }:

with lib;

let cfg = config.profiles.sparky-sd-mac;
in {
  options.profiles.sparky-sd-mac = {
    enable = mkEnableOption (mdDoc ''
      Enable the SPARKY SD-MAC profile.
      Use the serial number of the SD-Card for generating a unique and persistend MAC address.
      Useful for devices that don't have a unique MAC address like the NanoPi R2S.
    '');
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
    macInterfaceName = mkOption {
      type = types.str;
      description = mdDoc ''
        The MAC address of this interface will be set to the generated MAC.
      '';
    };
  };

  config = mkIf cfg.enable {
    # SD-MAC setup
    systemd.services.sdmac-setup = {
      description = "SD-MAC Setup";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      path = with pkgs; [ iproute2 gnused gawk ];
      serviceConfig = {
        Restart = "on-failure";
        RestartSec = 2;
        Type = "oneshot";
      };
      script = ''
        set -euo pipefail

        MAC_SUFFIX=$(cat /sys/block/${cfg.blockDeviceName}/device/serial | md5sum | awk '{ print $1 }' | head -c 6 | sed -e 's/./&:/2' -e 's/./&:/5' | tr -d '\n')
        MAC_ADDRESS="${cfg.macPrefix}:$MAC_SUFFIX"

        ip link set dev ${cfg.macInterfaceName} down
        ip link set dev ${cfg.macInterfaceName} address $MAC_ADDRESS
        ip link set dev ${cfg.macInterfaceName} up
      '';
    };
  };
}
