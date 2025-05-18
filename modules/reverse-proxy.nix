{ config, lib, ... }:
{
  options.my-services.reverse-proxy = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
    domain = mkOption {
      type = types.str;
    };
    services = mkOption {
      type =
        with types;
        attrsOf (
          submodule (
            { name, ... }:
            {
              options = {
                port = mkOption {
                  type = port;
                };
                hostname = mkOption { readOnly = true; };
                url = mkOption { readOnly = true; };
              };
              config = {
                hostname = "${name}.${config.my-services.reverse-proxy.domain}";
                url = "http://${name}.${config.my-services.reverse-proxy.domain}";
              };
            }
          )
        );
    };
  };
  config =
    let
      cfg = config.my-services.reverse-proxy;
    in
    lib.mkIf config.my-services.reverse-proxy.enable {
      networking.firewall.allowedTCPPorts = [
        80
        443
      ];

      services.caddy = {
        enable = true;
        virtualHosts = lib.mapAttrs' (
          name:
          { hostname, port, ... }:
          {
            name = "http://${hostname}";
            value.extraConfig = ''
              reverse_proxy http://localhost:${toString port}
            '';
          }
        ) cfg.services;
      };
    };
}
