{
  config,
  lib,
  ...
}:
{
  services.sonarr.enable = true;

  # media group owns all media
  users.users.sonarr.extraGroups = [ "media" ];
  # Don't let others write to our files
  systemd.services.sonarr.serviceConfig.UMask = lib.mkForce "0002";

  my.services.sonarr = rec {
    name = "Sonarr";
    url = "sonarr.home.mpardalos.com";
    port = config.services.sonarr.settings.server.port;
    order = 30;
    serviceName = "sonarr.service";
    icon.url = "${url}/favicon.ico";
  };
}
