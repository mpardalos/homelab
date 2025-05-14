{ config, lib, ... }:
{
  options.my-services.torrents = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
    prowlarr.port = mkOption { type = types.port; };
    qbittorrent.webui-port = mkOption { type = types.port; };
    gluetun = {
      http-proxy-port = mkOption { type = types.port; };
      shadowsocks-port = mkOption { type = types.port; };
    };
  };
  config =
    let
      services-cfg = config.my-services;
      cfg = config.my-services.torrents;
      qbittorrent-url = "http://torrents.${config.my-services.domain}";
      prowlarr-url = "http://prowlarr.${config.my-services.domain}";
    in
    lib.mkIf cfg.enable {
      virtualisation = {
        containers.enable = true;
        podman.enable = true;
      };

      networking.firewall.allowedTCPPorts = [
        cfg.gluetun.http-proxy-port
        cfg.gluetun.shadowsocks-port
        # For caddy
        80
        443
      ];

      networking.firewall.allowedUDPPorts = [
        cfg.gluetun.shadowsocks-port
      ];

      virtualisation.quadlet =
        let
          inherit (config.virtualisation.quadlet) networks pods;
        in
        {
          containers = {
            prowlarr.containerConfig = {
              image = "lscr.io/linuxserver/prowlarr:latest";
              autoUpdate = "registry";
              volumes = [ "prowlarr-config:/config" ];
              pod = pods.torrent.ref;
              environments = config.my-services.container-env // config.my-services.linuxserver-container-env;
            };
            qbittorrent.containerConfig = {
              image = "lscr.io/linuxserver/qbittorrent:latest";
              autoUpdate = "registry";
              volumes = [
                "${services-cfg.datadir}:/data"
                "qbittorrent-config:/config"
              ];
              pod = pods.torrent.ref;
              environments =
                config.my-services.container-env
                // config.my-services.linuxserver-container-env
                // {
                  WEBUI_PORT = toString cfg.qbittorrent.webui-port;
                };
            };
            gluetun.containerConfig = {
              image = "docker.io/qmcgaw/gluetun:latest";
              pod = pods.torrent.ref;

              # Required by gluetun
              addCapabilities = [ "NET_ADMIN" ];

              devices = [ "/dev/net/tun:/dev/net/tun" ];
              podmanArgs = [ "--security-opt label=disable" ];

              environments = config.my-services.container-env // {
                # AirVPN provider
                VPN_SERVICE_PROVIDER = "airvpn";
                VPN_TYPE = "wireguard";
                # FIXME: THIS IS A SECRET
                WIREGUARD_PRIVATE_KEY = "'"..."'";
                WIREGUARD_PRESHARED_KEY = "'"..."'";
                WIREGUARD_ADDRESSES = "'10.184.78.106/32,fd7d:76ee:e68f:a993:e4e0:25eb:59c8:f8df/128'";
                SERVER_COUNTRIES = "'United Kingdom'";

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
                # # Transferred from previous config, not sure why it's used
                # "8000:8000"
                "0.0.0.0:${toString cfg.gluetun.http-proxy-port}:8888"
                "0.0.0.0:${toString cfg.gluetun.shadowsocks-port}:8388/tcp"
                "0.0.0.0:${toString cfg.gluetun.shadowsocks-port}:8388/udp"
                "127.0.0.1:${toString cfg.qbittorrent.webui-port}:8080"
                "127.0.0.1:${toString cfg.prowlarr.port}:9696"
              ];
            };
          };
        };

      services.caddy = {
        enable = true;
        virtualHosts = {
          ${qbittorrent-url}.extraConfig = ''
            reverse_proxy http://localhost:${toString cfg.qbittorrent.webui-port}
          '';
          ${prowlarr-url}.extraConfig = ''
            reverse_proxy http://localhost:${toString cfg.prowlarr.port}
          '';
        };
      };

      services.olivetin.settings.actions = [
        {
          title = "Restart prowlarr";
          shell = "systemctl restart prowlarr.service";
          timeout = 10;
          icon = ''<img src = "${prowlarr-url}/favicon.ico" width = "48px"/>'';
        }
        {
          title = "Restart qbittorrent";
          shell = "systemctl restart qbittorrent.service";
          timeout = 10;
          icon = ''<img src = "${qbittorrent-url}/images/qbittorrent-tray.svg" width = "48px"/>'';
        }
        {
          title = "Restart gluetun";
          shell = "systemctl restart gluetun.service";
          timeout = 10;
          icon = ''<iconify-icon icon="flat-color-icons:lock" width="48"></iconify-icon>'';
        }
      ];
    };
}
