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

  my.services.sonarr = {
    port = config.services.sonarr.settings.server.port;
    order = 30;
    icon.path = "favicon.ico";
  };
}
