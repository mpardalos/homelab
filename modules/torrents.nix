{ config, ... }:
{
  nixarr = {
    enable = true;
    mediaDir = "/data/media";
    stateDir = "/data/nixarr";
    vpn = {
      enable = true;
      wgConf = "/data/wg.conf";
    };
    transmission = {
      enable = true;
      vpn.enable = true;
      peerPort = 37494;
      extraSettings = {
        download-dir = "/data/downloads/";
        incomplete-dir = "/data/downloads/.incomplete/";
        # Needed to access transmission from a DNS name
        rpc-host-whitelist-enabled = false;
      };
    };
    prowlarr.enable = true;
  };

  my-services.reverse-proxy.services = {
    torrents.port = config.nixarr.transmission.uiPort;
    prowlarr.port = config.nixarr.prowlarr.port;
  };
}
