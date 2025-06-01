{
  config,
  lib,
  ...
}:
{
  options.my-services.sonarr.enable = lib.mkEnableOption "Sonarr";
  config =
    let
      cfg = config.my-services.sonarr;
      port = config.services.sonarr.settings.server.port;
      service-name = "sonarr";
      my-url = config.my-services.reverse-proxy.services.${service-name}.url;
    in
    lib.mkIf cfg.enable {
      services.sonarr.enable = true;

      my-services.reverse-proxy.services = {
        ${service-name}.port = port;
      };

      my-services.olivetin.service-buttons.${service-name} = {
        serviceName = "${service-name}.service";
        icon.url = "${my-url}/favicon.ico";
      };
    };
}
