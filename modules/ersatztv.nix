{
  config,
  lib,
  ...
}:
let
  image = "docker.io/jasongdove/ersatztv";
  port = 8409;
  service-name = "ersatztv";
  my-url = config.my-services.reverse-proxy.services.${service-name}.url;
in
{
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

  my-services.reverse-proxy.services.${service-name}.port = port;

  my-services.service-buttons.${service-name} = {
    serviceName = "${service-name}.service";
    icon.url = "${my-url}/favicon.ico";
  };
}
