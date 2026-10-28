{ config, ... }:
{
  services.seerr = {
    enable = true;
    stateRevision = 1; # We never had the old version installed
  };
  my.services.seerr = rec {
    port = 5055;
    order = 20;
    icon.path = "favicon-32x32.png";
  };
}
