{
    inputs = {
        nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
        quadlet-nix.url = "github:SEIAROTg/quadlet-nix";
        quadlet-nix.inputs.nixpkgs.follows = "nixpkgs";
    };
    outputs = { nixpkgs, quadlet-nix, ... }@attrs: {
        nixosConfigurations.nixie = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [
                ./nixie/configuration.nix
                quadlet-nix.nixosModules.quadlet
            ];
        };
    };
}
