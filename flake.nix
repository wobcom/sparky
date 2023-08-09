{
  description = "NixOS Modules for a network reliability and connectivity testing infrastructure";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.05";
  };

  outputs = { self, nixpkgs, ... }: {
    nixosModules.probe = ./profiles/probe;
    nixosModules.sparky-web = ./profiles/sparky-web;
    nixosModules.tailnet = ./profiles/tailnet;
    nixosModules.ztp-image = ./profiles/ztp-image;
    nixosModules.iperf3-exporter = ./modules/iperf3-exporter;
    nixosModules.default = ./modules.nix;

    overlays.default = (import ./pkgs);
  };
}
