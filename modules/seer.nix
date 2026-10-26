{
  services.seerr = {
    enable = true;
    stateRevision = 1; # We never had the old version installed
  };
  my-services.reverse-proxy.services.seerr.port = 5055;
}
