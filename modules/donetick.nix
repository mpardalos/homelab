{
  config,
  lib,
  ...
}:
let
  image = "docker.io/donetick/donetick";
  port = 2021;
  service-name = "donetick";
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
      "${service-name}-config:/donetick-data"
    ];
    environments = config.my-services.container-env // {
      DT_ENV = "selfhosted";
      DT_SQLITE_PATH = "/donetick-data/donetick.db";
      DT_JWT_SECRET = "1iJ8qMu78-_-DmWCYF7d5s159WpfmDRMgnbR5P4qTw8=";
	  };
  };

  my-services.reverse-proxy.services = {
    ${service-name}.port = port;
  };

  my-services.service-buttons.${service-name} = {
    serviceName = "${service-name}.service";
    icon.url = "${my-url}/favicon.ico";
  };
}
