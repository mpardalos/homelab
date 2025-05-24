{ config, lib, ... }:
{
  options.my-services.ersatztv = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
    port = mkOption { type = types.port; };
  };
  config = lib.mkIf config.my-services.sonarr.enable (
    let
      my-url = config.my-services.reverse-proxy.services.ersatztv.url;
    in
    {
      virtualisation = {
        containers.enable = true;
        podman.enable = true;
      };

      virtualisation.quadlet.containers = {
        ersatztv.containerConfig = {
          image = "docker.io/jasongdove/ersatztv";
          autoUpdate = "registry";
          publishPorts = [ "127.0.0.1:${toString config.my-services.ersatztv.port}:8409" ];
          volumes = [
            "${config.my-services.datadir}:/data:ro"
            "ersatztv-config:/root/.local/share/ersatztv"
          ];
          environments = config.my-services.container-env;
        };
      };

      my-services.reverse-proxy.services = {
        ersatztv.port = config.my-services.ersatztv.port;
      };

      my-services.olivetin.service-buttons.ersatztv = {
        serviceName = "ersatztv.service";
        icon.url = "${my-url}/favicon.ico";
      };
    }
  );
}
