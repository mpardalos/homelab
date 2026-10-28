{ config, pkgs, lib, ... }:
let
  localDomain = "home.mpardalos.com";
  tsDomain = "ts.mpardalos.com";
  tsAddr = "100.84.230.81"; # This node's tailscale address
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
      tls_resolvers 1.1.1.1
    '';
    virtualHosts = lib.concatMapAttrs (
      name:
      { port, ... }:
      {
        "${name}.${localDomain}".extraConfig = "reverse_proxy http://localhost:${toString port}";
        "${name}.${tsDomain}".extraConfig = "reverse_proxy http://localhost:${toString port}";
      }
    ) config.my.services;
  };

  # Point services to this host on the tailnet
  networking.firewall.allowedUDPPorts = [ 53 ];
  services.coredns.enable = true;
  services.coredns.config = lib.join "\n" (
    [
      ".:53 {"
      "  hosts { "]
    ++ lib.mapAttrsToList (
      name: _: "    ${tsAddr} ${name}.${tsDomain}"
    ) config.my.services
    ++ [
      "  }"
      "}"
    ]
  );
}
