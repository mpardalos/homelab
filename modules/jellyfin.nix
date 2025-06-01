{
  config,
  lib,
  ...
}:
{
  options.my-services.jellyfin.enable = lib.mkEnableOption "Jellyfin";
  config =
    let
      cfg = config.my-services.jellyfin;
      port = 8096;
      service-name = "jellyfin";
      my-url = config.my-services.reverse-proxy.services.${service-name}.url;
    in
    lib.mkIf cfg.enable {
      virtualisation.containers.enable = true;
      virtualisation.podman.enable = true;

      virtualisation.quadlet.containers.${service-name}.containerConfig = {
        image = "lscr.io/linuxserver/jellyfin:latest";
        autoUpdate = "registry";
        publishPorts = [
          "127.0.0.1:${toString port}:${toString port}"
        ];
        volumes = [
          "${config.my-services.datadir}:/data"
          "${service-name}-config:/config"
        ];
        devices = [
          "/dev/dri:/dev/dri"
        ];
        environments =
          config.my-services.container-env
          // config.my-services.linuxserver-container-env
          // {
            JELLYFIN_PublishedServerUrl = my-url;
            DOCKER_MODS = "linuxserver/mods:jellyfin-opencl-intel";
          };
      };

      my-services.reverse-proxy.services = {
        ${service-name}.port = 8096;
      };

      my-services.olivetin.service-buttons.${service-name} = {
        serviceName = "${service-name}.service";
        icon.url = "${my-url}/web/favicon.png";
      };
    };
}
