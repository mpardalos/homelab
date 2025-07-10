{
  config,
  lib,
  ...
}:
{
  options.my-services.jellyfin.enable = lib.mkEnableOption "Jellyfin";
  config =
    let
      cfg = config.my-services.jellyfin;
      port = 8096;
      service-name = "jellyfin";
      my-url = config.my-services.reverse-proxy.services.${service-name}.url;
    in
    lib.mkIf cfg.enable {
      services.jellyfin.enable = true;

      my-services.reverse-proxy.services = {
        ${service-name}.port = port;
      };

      my-services.olivetin.service-buttons.${service-name} = {
        serviceName = "${service-name}.service";
        icon.url = "${my-url}/web/favicon.png";
      };
    };
}
