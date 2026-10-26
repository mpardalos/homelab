{
  config,
  lib,
  ...
}:
let
  image = "docker.io/donetick/donetick";
  port = 2021;
in
{
  virtualisation.containers.enable = true;
  virtualisation.podman.enable = true;

  virtualisation.quadlet.containers.donetick.containerConfig = {
    inherit image;
    autoUpdate = "registry";
    publishPorts = [
      "127.0.0.1:${toString port}:${toString port}"
    ];
    volumes = [
      "${config.my.datadir}:/data:ro"
      "donetick-config:/donetick-data"
    ];
    environments = config.my.container-env // {
      DT_ENV = "selfhosted";
      DT_SQLITE_PATH = "/donetick-data/donetick.db";
      DT_JWT_SECRET = "1iJ8qMu78-_-DmWCYF7d5s159WpfmDRMgnbR5P4qTw8=";
	  };
  };

  my.services.donetick = rec {
    name = "Donetick";
    order = 80;
    inherit port;
    serviceName = "donetick.service";
    url = "donetick.home.mpardalos.com";
    icon.url = "${url}/logo.svg";
  };
}
