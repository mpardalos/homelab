{
  pkgs,
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
      services.jellyfin = {
        enable = true;
        hardwareAcceleration = {
          enable = true;
          type = "vaapi";
          device = "/dev/dri/renderD128";
        };
      };

      systemd.services.jellyfin.environment.LIBVA_DRIVER_NAME = "iHD"; # or i965 for older GPUs
      environment.sessionVariables = { LIBVA_DRIVER_NAME = "iHD"; };
      users.users.jellyfin.extraGroups = [ "render" "video" ];

      hardware.graphics.enable = true;
      hardware.graphics.extraPackages = [ pkgs.intel-media-driver ];

      my-services.reverse-proxy.services = {
        ${service-name}.port = port;
      };

      my-services.olivetin.service-buttons.${service-name} = {
        serviceName = "${service-name}.service";
        icon.url = "${my-url}/web/favicon.png";
      };
    };
}
