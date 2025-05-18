{ config, lib, ... }:
{
  options.my-services.radarr = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
    port = mkOption { type = types.port; };
  };
  config = lib.mkIf config.my-services.sonarr.enable (
    let
      my-url = config.my-services.reverse-proxy.services.radarr.url;
    in
    {
      virtualisation = {
        containers.enable = true;
        podman.enable = true;
      };

      virtualisation.quadlet.containers = {
        radarr.containerConfig = {
          image = "lscr.io/linuxserver/radarr:latest";
          autoUpdate = "registry";
          publishPorts = [ "127.0.0.1:${toString config.my-services.radarr.port}:7878" ];
          volumes = [
            "${config.my-services.datadir}:/data"
            "radarr-config:/config"
          ];
          environments = config.my-services.container-env // config.my-services.linuxserver-container-env;
        };
      };

      my-services.reverse-proxy.services = {
        radarr.port = config.my-services.radarr.port;
      };

      my-services.olivetin.service-buttons.radarr = {
        serviceName = "radarr.service";
        icon.url = "${my-url}/favicon.ico";
      };
    }
  );
}
