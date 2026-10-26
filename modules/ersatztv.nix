{
  config,
  lib,
  ...
}:
let
  image = "docker.io/jasongdove/ersatztv";
  port = 8409;
  service-name = "ersatztv";
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

  my.services.ersatztv = rec {
    inherit port;
    url = "ersatztv.home.mpardalos.com";
    serviceName = "${service-name}.service";
    icon.url = "${url}/favicon.ico";
  }
}
