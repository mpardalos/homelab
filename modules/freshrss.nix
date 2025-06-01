{
  config,
  lib,
  ...
}:
{
  options.my-services.freshrss.enable = lib.mkEnableOption "FreshRSS";
  config =
    let
      cfg = config.my-services.freshrss;
      image = "lscr.io/linuxserver/freshrss:latest";
      port = 80;
      service-name = "freshrss";
      my-url = config.my-services.reverse-proxy.services.${service-name}.url;
    in
    lib.mkIf cfg.enable {
      virtualisation.containers.enable = true;
      virtualisation.podman.enable = true;

      virtualisation.quadlet.containers.${service-name}.containerConfig = {
        inherit image;
        autoUpdate = "registry";
        publishPorts = [
          "127.0.0.1:${toString port}:${toString port}"
        ];
        volumes = [
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
