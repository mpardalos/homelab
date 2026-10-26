{
  config,
  lib,
  ...
}:
let
  service-name = "radarr";
  port = config.services.radarr.settings.server.port;
  my-url = config.my-services.reverse-proxy.services.${service-name}.url;
in
{
  services.radarr.enable = true;

  my-services.reverse-proxy.services.${service-name}.port = port;

  my-services.service-buttons.${service-name} = {
    serviceName = "${service-name}.service";
    icon.url = "${my-url}/favicon.ico";
  };
}
