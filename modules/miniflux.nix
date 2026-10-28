{ config, lib, pkgs, ... }:
let
  dbUser = "miniflux";
  dbPassword = "m1n1fl0x3r0x1";
  dbDatabase = "miniflux";
  service-name = "miniflux";
  port = 8080;
  adminUsername = "mpardalos";
  adminPassword = "Poet-Quench0-Footwork";
in
{
  containers.miniflux = {
    autoStart = true;
    config = { config, pkgs, lib, ... }: {
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
    };
  };

  my.services.miniflux = {
    inherit port;
    order = 70;
    serviceName = "container@miniflux.service";
    # icon.url = "${url}/favicon.ico";
  };
}
