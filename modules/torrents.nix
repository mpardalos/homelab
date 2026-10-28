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
        # I don't use this
        watch-dir-enabled = false;
      };
    };
    prowlarr.enable = true;
  };

  my.services = {
    prowlarr = rec {
      port = config.nixarr.prowlarr.port;
      order = 50;
      icon.path = "favicon.ico";
    };
    torrents = {
      port = config.nixarr.transmission.uiPort;
      order = 60;
      icon.path = "transmission/web/images/favicon.svg";
    };
  };
}
