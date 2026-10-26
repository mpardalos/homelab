{ config, pkgs, lib, ... }:
{
  options.my-services.reverse-proxy = with lib; {
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
    {
      networking.firewall.allowedTCPPorts = [
        80
        443
      ];

      systemd.services.caddy.serviceConfig.EnvironmentFile = "/home/mpardalos/netlify.env";

      services.caddy = {
        enable = true;
        package = pkgs.caddy.withPlugins {
          plugins = [ "github.com/caddy-dns/netlify@v1.2.0" ];
          hash = "sha256-hMpvx4RAvfvwvm/M/yAWY1LuEkFCR7rdkhrbFwcaA7E=";
        };
        globalConfig = ''
          acme_dns netlify {env.NETLIFY_AUTH_TOKEN}
        '';
        virtualHosts = lib.mapAttrs' (
          name:
          { hostname, port, ... }:
          {
            name = hostname;
            value.extraConfig = ''
              reverse_proxy http://localhost:${toString port}
            '';
          }
        ) cfg.services;
      };
    };
}
