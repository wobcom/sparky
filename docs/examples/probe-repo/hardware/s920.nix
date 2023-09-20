{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "ehci_pci" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
    autoResize = true;
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/ESP";
    fsType = "vfat";
  };

  # serial stuff
  boot.kernelParams = [
    "console=ttyS0,115200"
    "console=tty1"
  ];

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
}
