{ config, ... }:
{
  services.seerr = {
    enable = true;
    stateRevision = 1; # We never had the old version installed
  };
  my.services.seerr = rec {
    name = "Seerr";
    url = "seerr.home.mpardalos.com";
    port = 5055;
    order = 20;
    icon.url = "${url}/favicon-32x32.png";
  };
}
