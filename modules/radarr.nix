{
  config,
  lib,
  ...
}:
{
  options.my-services.radarr.enable = lib.mkEnableOption "Radarr";
  config =
    let
      cfg = config.my-services.radarr;
      port = config.services.radarr.settings.server.port;
      service-name = "radarr";
      my-url = config.my-services.reverse-proxy.services.${service-name}.url;
    in
    lib.mkIf cfg.enable {
      services.radarr.enable = true;

      my-services.reverse-proxy.services = {
        ${service-name}.port = port;
      };

      my-services.olivetin.service-buttons.${service-name} = {
        serviceName = "${service-name}.service";
        icon.url = "${my-url}/favicon.ico";
      };
    };
}
