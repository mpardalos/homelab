{
  config,
  lib,
  ...
}:
let
  image = "lscr.io/linuxserver/freshrss:latest";
  port = 5723;
  service-name = "freshrss";
in
{
  virtualisation.containers.enable = true;
  virtualisation.podman.enable = true;

  virtualisation.quadlet.containers.${service-name}.containerConfig = {
    inherit image;
    autoUpdate = "registry";
    publishPorts = [
      "127.0.0.1:${toString port}:80"
    ];
    volumes = [
      "${service-name}-config:/config"
    ];
    environments = config.my-services.container-env // config.my-services.linuxserver-container-env;
  };

  my.services.freshrss = rec {
    inherit port;
    icon.path = "favicon.ico";
  };
}
