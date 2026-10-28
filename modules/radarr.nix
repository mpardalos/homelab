{
  config,
  lib,
  ...
}:
{
  services.radarr.enable = true;

  # media group owns all media
  users.users.radarr.extraGroups = [ "media" ];
  # Don't let others write to our files
  systemd.services.radarr.serviceConfig.UMask = lib.mkForce "0002";

  my.services.radarr = {
    port = config.services.radarr.settings.server.port;
    order = 40;
    icon.path = "favicon.ico";
  };
}
