{
  config,
  lib,
  ...
}:
{
  options.my-services.torrents.enable = lib.mkEnableOption "Torrent-related services";
  config =
    let
      prowlarr-image = "lscr.io/linuxserver/prowlarr:latest";
      prowlarr-port = 9696;
      qbittorrent-image = "lscr.io/linuxserver/qbittorrent:latest";
      qbittorrent-webui-port = 8080;
      gluetun-image = "docker.io/qmcgaw/gluetun:latest";
      gluetun-http-proxy-port = 8888;
      gluetun-shadowsocks-port = 8388;

      cfg = config.my-services.torrents;
      datadir = config.my-services.datadir;
      qbittorrent-url = config.my-services.reverse-proxy.services.torrents.url;
      prowlarr-url = config.my-services.reverse-proxy.services.prowlarr.url;
    in
    lib.mkIf cfg.enable {
      virtualisation.containers.enable = true;
      virtualisation.podman.enable = true;

      networking.firewall.allowedTCPPorts = [
        gluetun-http-proxy-port
        gluetun-shadowsocks-port
      ];

      networking.firewall.allowedUDPPorts = [
        gluetun-shadowsocks-port
      ];

      virtualisation.quadlet =
        let
          inherit (config.virtualisation.quadlet) networks pods;
        in
        {
          containers = {
            prowlarr.containerConfig = {
              image = prowlarr-image;
              autoUpdate = "registry";
              volumes = [ "prowlarr-config:/config" ];
              pod = pods.torrent.ref;
              environments = config.my-services.container-env // config.my-services.linuxserver-container-env;
            };
            qbittorrent.containerConfig = {
              image = qbittorrent-image;
              autoUpdate = "registry";
              volumes = [
                "${datadir}:/data"
                "qbittorrent-config:/config"
              ];
              pod = pods.torrent.ref;
              environments =
                config.my-services.container-env
                // config.my-services.linuxserver-container-env
                // {
                  WEBUI_PORT = toString qbittorrent-webui-port;
                };
            };
            gluetun.containerConfig = {
              image = gluetun-image;
              pod = pods.torrent.ref;

              # Required by gluetun
              addCapabilities = [ "NET_ADMIN" ];

              devices = [ "/dev/net/tun:/dev/net/tun" ];
              podmanArgs = [ "--security-opt" "label=disable" ];

              environments = config.my-services.container-env // {
                # AirVPN provider
                VPN_SERVICE_PROVIDER = "airvpn";
                VPN_TYPE = "wireguard";
                # FIXME: THIS IS A SECRET
                WIREGUARD_PRIVATE_KEY = ""..."";
                WIREGUARD_PRESHARED_KEY = ""..."";
                WIREGUARD_ADDRESSES = "10.184.78.106/32,fd7d:76ee:e68f:a993:e4e0:25eb:59c8:f8df/128";
                SERVER_COUNTRIES = "United Kingdom";

                # Port forward
                FIREWALL_VPN_INPUT_PORTS = "37494";

                # HTTP proxy
                HTTPPROXY = "on";
                HTTPPROXY_LOG = "on";

                # Shadowsocks proxy
                SHADOWSOCKS = "on";
                SHADOWSOCKS_PASSWORD = "shadowsocks";

                # Disable DNS-over-TLS
                DOT = "off";
                DNS_KEEP_NAMESERVER = "on";

                # Allow access to local network
                FIREWALL_OUTBOUND_SUBNETS = "192.168.0.0/24";
              };
            };
          };
          pods = {
            torrent.podConfig = {
              publishPorts = [
                "0.0.0.0:${toString gluetun-http-proxy-port}:${toString gluetun-http-proxy-port}"
                "0.0.0.0:${toString gluetun-shadowsocks-port}:${toString gluetun-shadowsocks-port}/tcp"
                "0.0.0.0:${toString gluetun-shadowsocks-port}:${toString gluetun-shadowsocks-port}/udp"
                "127.0.0.1:${toString qbittorrent-webui-port}:${toString qbittorrent-webui-port}"
                "127.0.0.1:${toString prowlarr-port}:${toString prowlarr-port}"
              ];
            };
          };
        };

      my-services.reverse-proxy.services = {
        torrents.port = qbittorrent-webui-port;
        prowlarr.port = prowlarr-port;
      };

      my-services.olivetin.service-buttons = {
        prowlarr = {
          serviceName = "prowlarr.service";
          icon.url = "${prowlarr-url}/favicon.ico";
        };
        qbittorrent = {
          serviceName = "qbittorrent.service";
          icon.url = "${qbittorrent-url}/images/qbittorrent-tray.svg";
        };
        gluetun = {
          serviceName = "gluetun.service";
          icon.html = ''<iconify-icon icon="flat-color-icons:lock" width="48"></iconify-icon>'';
        };
      };
    };
}
