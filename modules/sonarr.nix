{ config, lib, ... }:
{
  options.my-services.sonarr = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
    port = mkOption { type = types.str; };
  };
  config = lib.mkIf config.my-services.sonarr.enable {
    virtualisation = {
      containers.enable = true;
      podman.enable = true;
    };

    virtualisation.quadlet.containers = {
      sonarr.containerConfig = {
        image = "lscr.io/linuxserver/sonarr:latest";
        autoUpdate = "registry";
        publishPorts = [ "${config.my-services.sonarr.port}:8989" ];
        volumes = [
          "${config.my-services.datadir}:/data"
          "sonarr-config:/config"
        ];
        environments = {
          PUID = config.my-services.PUID;
          PGID = config.my-services.PGID;
          UMASK = "002";
          TZ = config.time.timeZone;
        };
      };
    };

    services.caddy =
      let
        domain = config.my-services.domain;
        FQDN = "${config.networking.hostName}.${domain}";
      in
      {
        enable = true;
        virtualHosts."http://sonarr.${domain}".extraConfig = ''
          reverse_proxy http://${FQDN}:${config.my-services.sonarr.port}
        '';
      };
  };
}
