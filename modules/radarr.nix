{
  config,
  lib,
  ...
}:
{
  services.radarr.enable = true;

  my.services.radarr = rec {
    name = "Radarr";
    port = config.services.radarr.settings.server.port;
    url = "radarr.home.mpardalos.com";
    order = 40;
    serviceName = "radarr.service";
    icon.url = "${url}/favicon.ico";
  };
}
