{ config, lib, pkgs, ... }:

{
  imports = [
    ./environment.nix
    ./users.nix
  ];
  
  config = {
    services.openssh = {
      enable = true;
      openFirewall = false; # gets configured explicit in the probe profile
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
      };
      extraConfig = ''
        AuthenticationMethods publickey
      '';
      authorizedKeysFiles = lib.mkForce [
        "/etc/ssh/authorized_keys.d/%u"
      ];
    };

    nix = {
      gc = {
        automatic = true;
        options = "--delete-older-than 7d";
      };
      settings.trusted-users = [ "@wheel" ];
      extraOptions = ''
        experimental-features = nix-command flakes
      '';
    };

    users.mutableUsers = false;
    security.sudo.wheelNeedsPassword = false;

    # hardening
    boot.specialFileSystems = lib.mkIf (!config.security.rtkit.enable && !config.security.polkit.enable) {
      "/proc".options = lib.optionals (!config.security.rtkit.enable && !config.security.polkit.enable) [ "hidepid=2" ];
    };
    boot.kernel.sysctl."kernel.dmesg_restrict" = 1;

    environment.systemPackages = with pkgs; [
      vim
      git
      curl
      wget
      htop
      jq
    ];

    networking.nameservers = [
      "1.1.1.1"
      "1.0.0.1"
      "2606:4700:4700::1111"
      "2606:4700:4700::1001"
    ];

    networking.firewall.logRefusedConnections = false;
    networking.nftables.enable = true; # required for probe-module
  };
}