{
  config,
  lib,
  ...
}:
{
  services.sonarr.enable = true;

  my.services.sonarr = rec {
    name = "Sonarr";
    url = "sonarr.home.mpardalos.com";
    port = config.services.sonarr.settings.server.port;
    order = 30;
    serviceName = "sonarr.service";
    icon.url = "${url}/favicon.ico";
  };
}
