{
  config,
  lib,
  ...
}:
{
  options.my-services.ersatztv.enable = lib.mkEnableOption "ErsatzTV";
  config =
    let
      image = "docker.io/jasongdove/ersatztv";
      port = 8409;
      cfg = config.my-services.ersatztv;
      service-name = "ersatztv";
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
          "${config.my-services.datadir}:/data:ro"
          "${service-name}-config:/root/.local/share/ersatztv"
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
