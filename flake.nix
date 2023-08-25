{
  description = "NixOS Modules for a network reliability and connectivity testing infrastructure";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }: {
    nixosModules.sparky-probe = ./profiles/sparky-probe;
    nixosModules.sparky-web = ./profiles/sparky-web;
    nixosModules.sparky-tailnet = ./profiles/sparky-tailnet;
    nixosModules.sparky-ztp-image = ./profiles/sparky-ztp-image;
    nixosModules.iperf3-exporter = ./modules/iperf3-exporter;
    nixosModules.default = ./modules.nix;

    overlays.default = (import ./pkgs);
  } // flake-utils.lib.eachDefaultSystem (system: let
    pkgs = nixpkgs.legacyPackages.${system};
  in {
    packages = {
      prometheus-iperf3-exporter = pkgs.callPackage ./pkgs/iperf3-exporter { };
      sparky-web = pkgs.callPackage ./pkgs/sparky-web { };
    };
  });
}
