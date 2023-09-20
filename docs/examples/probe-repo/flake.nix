{
  description = "SPARKY Probes";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    sparky.url = "github:wobcom/sparky";
    sparky.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, sparky, ... }@inputs: {

    nixosConfigurations = let
      inherit (nixpkgs.lib) removeSuffix hasSuffix mapAttrsToList optional splitString head last;
      inherit (builtins) map filter readDir readFile fromJSON listToAttrs substring;
      probes = map (x: removeSuffix ".json" x) (filter (x: hasSuffix ".json" x) (mapAttrsToList (n: v: n) (readDir ./probes)));
      ztp-images = map (x: removeSuffix ".nix" x) (filter (x: hasSuffix ".nix" x) (mapAttrsToList (n: v: n) (readDir ./ztp-image)));
      hosts = probes ++ ztp-images;

      # mapping of hardware to systems
      # when adding new hardware profiles, also add it to this mapping here
      hwSystems = {
        "s920" = "x86_64-linux";
        "r2s" = "aarch64-linux";
        "r2s-sd" = "aarch64-linux";
      };
    in listToAttrs (map (host:
      let
        hostSplit = splitString "_" host;
        hostname = head hostSplit;
        hardware = last hostSplit;
        isProbe = ((substring 0 16 hostname) != "sparky-ztp-image");
      in {
        name = hostname;
        value = nixpkgs.lib.nixosSystem {
          system = hwSystems."${hardware}";
          modules = [
            {
              nixpkgs.overlays = [
                sparky.overlays.default
              ];
            }
            ./common
            sparky.nixosModules.default
            (./hardware + "/${hardware}.nix")
          ] ++ optional isProbe
            (fromJSON (readFile (./. + "/probes/${host}.json")))
          ++ optional (!isProbe)
            (./ztp-image + "/${host}.nix")
          ;
        };
      }
    ) hosts);
  };
}
