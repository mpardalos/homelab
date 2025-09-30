{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    quadlet-nix.url = "github:SEIAROTg/quadlet-nix";
    deploy-rs.url = "github:serokell/deploy-rs";
    nixarr.url = "github:mpardalos/nixarr";
  };
  outputs =
    {
      self,
      nixpkgs,
      quadlet-nix,
      deploy-rs,
      nixarr,
      ...
    }@inputs:
    {
      nixosConfigurations.nixie = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          quadlet-nix.nixosModules.quadlet
          nixarr.nixosModules.default
          ./modules
          ./hosts/nixie
        ];
      };

      specialArgs = { inherit inputs; };

      deploy.nodes.nixie = {
        hostname = "nixie.home.mpardalos.com";
        profiles.system = {
          user = "root";
          path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.nixie;
          interactiveSudo = true;
        };
      };

      checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;

      devShells."x86_64-linux".default =
        let
          pkgs = nixpkgs.legacyPackages."x86_64-linux";
        in
        pkgs.mkShell {
          packages = [
            deploy-rs.packages."x86_64-linux".default
            pkgs.nixfmt-rfc-style
          ];
        };
    };
}
