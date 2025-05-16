{ config, lib, ... }:
{
  options.my-services.samba = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
    shares = mkOption {
      type =
        with types;
        attrsOf (submodule {
          options = {
            path = mkOption {
              type = str;
            };
          };
        });
    };
  };
  config =
    let
      cfg = config.my-services.samba;
    in
    lib.mkIf cfg.enable {
      services.samba-wsdd = {
        enable = true;
        openFirewall = true;
      };

      services.samba = {
        enable = true;
        openFirewall = true;
        nmbd.enable = true;
        settings = lib.mapAttrs (
          shareName: { path }: {
            "path" = path;
            "read only" = "yes";
            "browseable" = "yes";
            "guest ok" = "yes";
            "comment" = "Public samba share.";
          }
        ) cfg.shares;
      };
    };
}
