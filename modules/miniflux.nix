{ config, lib, pkgs, ... }:
{
  options.my-services.miniflux = with lib; {
    enable = mkEnableOption "Miniflux";
    port = mkOption { type = types.port; };
    adminUsername = mkOption { type = types.str; };
    adminPassword = mkOption { type = types.str; };
  };
  config = 
    let
      cfg = config.my-services.miniflux;
      dbUser = "miniflux";
      dbPassword = "m1n1fl0x3r0x1";
      dbDatabase = "miniflux";
      my-url = config.my-services.reverse-proxy.services.miniflux.url;
      service-name = "miniflux";
    in
    lib.mkIf cfg.enable {
      services.miniflux = {
        enable = true;
        adminCredentialsFile = pkgs.writeText "miniflux_creds" ''
            ADMIN_USERNAME=${cfg.adminUsername}
            ADMIN_PASSWORD=${cfg.adminPassword}
        '';
        config = {
          LISTEN_ADDR = "localhost:${toString cfg.port}";
        };
      };

      my-services.reverse-proxy.services = {
        ${service-name}.port = cfg.port;
      };

      my-services.olivetin.service-buttons.${service-name} = {
        serviceName = "${service-name}.service";
        icon.url = "${my-url}/web/favicon.png";
      };
    };
}
