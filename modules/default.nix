{ lib, config, ... }:
{
  imports = [
    ./samba.nix
    ./my-services.nix
  ];
}
