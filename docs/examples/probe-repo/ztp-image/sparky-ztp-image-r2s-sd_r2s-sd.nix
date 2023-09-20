{ lib, pkgs, modulesPath, ... }: {
  networking.hostName = "sparky-ztp-image-r2s";

  profiles.sparky-ztp-image = {
    enable = true;
    webURL = "https://sparky.example.com";
    macInterfaceName = "end0"; # interface to use the MAC address from for ZTP
  };

  profiles.sparky-sd-mac.enable = true;

  imports = [
    (modulesPath + "/installer/sd-card/sd-image-aarch64.nix")
  ];

  # We import sd-image-aarch64.nix so we can build a config.system.build.sdImage
  # But it imports some modules we don't want, so disable them
  disabledModules = [
    "profiles/base.nix"
    "profiles/all-hardware.nix"
  ];

  # enable zram swap
  zramSwap.enable = true;

  boot.initrd.availableKernelModules = [ "mmc_block" ];
  boot.initrd.includeDefaultModules = false;

  nixpkgs.config.allowUnfree = true; # needed for ubootRock64
  # at the time of writing the u-boot version from FireFly hasn't been successfully ported yet
  # so we use the one from Rock64
  sdImage.postBuildCommands = with pkgs; ''
    dd if=${ubootRock64}/idbloader.img of=$img conv=fsync,notrunc bs=512 seek=64
    dd if=${ubootRock64}/u-boot.itb of=$img conv=fsync,notrunc bs=512 seek=16384
  '';

  system.stateVersion = "23.05";
}