{
    inputs = {
        nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
        quadlet-nix = {
            url = "github:SEIAROTg/quadlet-nix";
            inputs.nixpkgs.follows = "nixpkgs";
        };
        deploy-rs.url = "github:serokell/deploy-rs";
    };
    outputs = { self, nixpkgs, quadlet-nix, deploy-rs, ... }@attrs: {
        nixosConfigurations.nixie = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [
                ./nixie/configuration.nix
                quadlet-nix.nixosModules.quadlet
            ];
        };

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
            let pkgs = nixpkgs.legacyPackages."x86_64-linux";
            in pkgs.mkShell {
                packages = [
                    deploy-rs.packages."x86_64-linux".default
                ];
            };
    };
}
