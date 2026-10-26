{
  pkgs,
  config,
  lib,
  ...
}:
{
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
  users.users.jellyfin.extraGroups = [ "render" "video" "media" ];
  systemd.services.jellyfin.serviceConfig.UMask = lib.mkForce "0002";

  hardware.graphics.enable = true;
  hardware.graphics.extraPackages = [ pkgs.intel-media-driver ];

  my.services.jellyfin = rec {
    name = "Jellyfin";
    port = 8096;
    order = 10;
    serviceName = "jellyfin.service";
    url = "jellyfin.home.mpardalos.com";
    icon.url = "${url}/web/favicon.bc8d51405ec040305a87.ico";
  };
}
