{ config, pkgs, lib, ... }:
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
      { url, port, ... }:
      {
        name = url;
        value.extraConfig = "reverse_proxy http://localhost:${toString port}";
      }
    ) config.my.services;
  };
}
