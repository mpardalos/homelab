{
  config,
  lib,
  ...
}:
{
  options.my-services.radarr.enable = lib.mkEnableOption "Radarr";
  config =
    let
      cfg = config.my-services.radarr;
      port = 7878;
      service-name = "radarr";
      my-url = config.my-services.reverse-proxy.services.${service-name}.url;
    in
    lib.mkIf cfg.enable {
      virtualisation.containers.enable = true;
      virtualisation.podman.enable = true;

      virtualisation.quadlet.containers.${service-name}.containerConfig = {
        image = "lscr.io/linuxserver/radarr:latest";
        autoUpdate = "registry";
        publishPorts = [
          "127.0.0.1:${toString port}:${toString port}"
        ];
        volumes = [
          "${config.my-services.datadir}:/data"
          "${service-name}-config:/config"
        ];
        environments = config.my-services.container-env // config.my-services.linuxserver-container-env;
      };

      my-services.reverse-proxy.services = {
        ${service-name}.port = port;
      };

      my-services.olivetin.service-buttons.${service-name} = {
        serviceName = "${service-name}.service";
        icon.url = "${my-url}/favicon.ico";
      };
    };
}
