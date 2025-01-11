{ config, lib, ... }:
{
  options.my-services.jellyfin = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
    port = mkOption { type = types.str; };
  };
  config = lib.mkIf config.my-services.sonarr.enable (
    let
      domain = config.my-services.domain;
      FQDN = "${config.networking.hostName}.${domain}";
    in
    {
      virtualisation = {
        containers.enable = true;
        podman.enable = true;
      };

      virtualisation.quadlet.containers = {
        jellyfin.containerConfig = {
          image = "lscr.io/linuxserver/jellyfin:latest";
          autoUpdate = "registry";
          publishPorts = [ "${config.my-services.jellyfin.port}:8096" ];
          volumes = [
            "${config.my-services.datadir}:/data"
            "jellyfin-config:/config"
          ];
          devices = [
            "/dev/dri:/dev/dri"
          ];
          environments = {
            PUID = config.my-services.PUID;
            PGID = config.my-services.PGID;
            UMASK = "002";
            TZ = config.time.timeZone;
            JELLYFIN_PublishedServerUrl = "jellyfin.${domain}";
            DOCKER_MODS = "linuxserver/mods:jellyfin-opencl-intel";
          };
        };
      };
      services.caddy = {
        enable = true;
        virtualHosts."http://jellyfin.${domain}".extraConfig = ''
          reverse_proxy http://${FQDN}:${config.my-services.jellyfin.port}
        '';
      };
    }
  );
}
