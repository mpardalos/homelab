{ config, lib, ... }:
{
  options.my-services.miniflux = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
    port = mkOption { type = types.port; };
    adminUsername = mkOption { type = types.string; };
    adminPassword = mkOption { type = types.string; };
  };
  config =
    let
      cfg = config.my-services.miniflux;
      dbUser = "miniflux";
      dbPassword = "m1n1fl0x3r0x1";
      dbDatabase = "miniflux";
    in
    lib.mkIf cfg.enable {
      virtualisation = {
        containers.enable = true;
        podman.enable = true;
      };

      networking.firewall.allowedTCPPorts = [
        80
        443
      ];

      virtualisation.quadlet.pods.miniflux.podConfig = {
        publishPorts = [
          "127.0.0.1:${toString cfg.port}:8080"
        ];
      };

      virtualisation.quadlet.containers =
        let
          inherit (config.virtualisation.quadlet) networks pods containers;
        in
        {
          # TODO: This needs to wait for postgres to actually be up and healthy
          miniflux-web.serviceConfig.depends = [ containers.miniflux-postgres.ref ];
          miniflux-web.containerConfig = {
            image = "docker.io/miniflux/miniflux:latest";
            autoUpdate = "registry";
            environments = config.my-services.container-env // {
              DATABASE_URL = "postgres://${dbUser}:${dbPassword}@localhost/${dbDatabase}?sslmode=disable";
              RUN_MIGRATIONS = "1";
              CREATE_ADMIN = "1";
              ADMIN_USERNAME = cfg.adminUsername;
              ADMIN_PASSWORD = cfg.adminPassword;
            };
            pod = pods.miniflux.ref;
          };
          miniflux-postgres.containerConfig = {
            image = "docker.io/postgres:17-alpine";
            autoUpdate = "registry";
            environments = config.my-services.container-env // {
              POSTGRES_USER = dbUser;
              POSTGRES_PASSWORD = dbPassword;
              POSTGRES_DB = dbDatabase;
            };
            volumes = [ "miniflux-db:/var/lib/postgresql/data" ];
            pod = pods.miniflux.ref;
          };
        };

      services.caddy = {
        enable = true;
        virtualHosts."http://miniflux.${config.my-services.domain}".extraConfig = ''
          reverse_proxy http://localhost:${toString cfg.port}
        '';
        virtualHosts."https://miniflux.${config.my-services.domain}".extraConfig = ''
          reverse_proxy http://localhost:${toString cfg.port}
        '';
      };
    };
}
