{ config, lib, pkgs, modulesPath, ... }:

{
  config = {
    networking.hostName = "sparky-ztp-image-s920";

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

    profiles.sparky-ztp-image = {
      enable = true;
      webURL = "https://sparky.example.com";
      macInterfaceName = "enp1s0"; # interface to use the MAC address from for ZTP
    };

    system.stateVersion = "23.05";
  };
}