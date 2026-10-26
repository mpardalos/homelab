{
  config,
  lib,
  ...
}:
let
  service-name = "sonarr";
  port = config.services.sonarr.settings.server.port;
  my-url = config.my-services.reverse-proxy.services.${service-name}.url;
in
{
  services.sonarr.enable = true;

  my-services.reverse-proxy.services.${service-name}.port = port;

  my-services.service-buttons.${service-name} = {
    serviceName = "${service-name}.service";
    icon.url = "${my-url}/favicon.ico";
  };
}
