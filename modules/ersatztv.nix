{
  config,
  lib,
  ...
}:
let
  image = "docker.io/jasongdove/ersatztv";
  port = 8409;
in
{
  virtualisation.containers.enable = true;
  virtualisation.podman.enable = true;

  virtualisation.quadlet.containers.ersatztv.containerConfig = {
    inherit image;
    autoUpdate = "registry";
    publishPorts = [
      "127.0.0.1:${toString port}:${toString port}"
    ];
    volumes = [
      "${config.my-services.datadir}:/data:ro"
      "ersatztv-config:/root/.local/share/ersatztv"
    ];
    environments = config.my-services.container-env // config.my-services.linuxserver-container-env;
  };

  my.services.ersatztv = rec {
    inherit port;
    icon.path = "favicon.ico";
  }
}
