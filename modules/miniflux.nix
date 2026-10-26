{ config, lib, pkgs, ... }:
let
  dbUser = "miniflux";
  dbPassword = "m1n1fl0x3r0x1";
  dbDatabase = "miniflux";
  my-url = config.my-services.reverse-proxy.services.miniflux.url;
  service-name = "miniflux";
  port = 8080;
  adminUsername = "mpardalos";
  adminPassword = "Poet-Quench0-Footwork";
in
{
  services.miniflux = {
    enable = true;
    adminCredentialsFile = pkgs.writeText "miniflux_creds" ''
            ADMIN_USERNAME=${adminUsername}
            ADMIN_PASSWORD=${adminPassword}
        '';
    config = {
      LISTEN_ADDR = "localhost:${toString port}";
    };
  };

  my-services.reverse-proxy.services.${service-name}.port = port;

  my-services.service-buttons.${service-name} = {
    serviceName = "${service-name}.service";
    icon.url = "${my-url}/web/favicon.png";
  };
}
