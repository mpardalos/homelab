{ config, lib, ... }:
{
  options.my-services.torrents = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
    prowlarr.port = mkOption { type = types.str; };
    qbittorrent.webui-port = mkOption { type = types.str; };
    gluetun = {
      http-proxy-port = mkOption { type = types.str; };
      shadowsocks-port = mkOption { type = types.str; };
    };
  };
  config =
    let
      services-cfg = config.my-services;
      cfg = config.my-services.torrents;
    in
    lib.mkIf cfg.enable {
      virtualisation = {
        containers.enable = true;
        podman.enable = true;
      };

      virtualisation.quadlet =
        let
          usualEnv = {
            PUID = config.my-services.PUID;
            PGID = config.my-services.PGID;
            UMASK = "002";
            TZ = config.time.timeZone;
          };

          inherit (config.virtualisation.quadlet) networks pods;
        in
        {
          containers = {
            prowlarr.containerConfig = {
              image = "lscr.io/linuxserver/prowlarr:latest";
              autoUpdate = "registry";
              volumes = [ "prowlarr-config:/config" ];
              pod = pods.torrent.ref;
              environments = usualEnv;
            };
            qbittorrent.containerConfig = {
              image = "lscr.io/linuxserver/qbittorrent:latest";
              autoUpdate = "registry";
              volumes = [
                "${services-cfg.datadir}:/data"
                "qbittorrent-config:/config"
              ];
              pod = pods.torrent.ref;
              environments = usualEnv // {
                WEBUI_PORT = "${cfg.qbittorrent.webui-port}";
              };
            };
            gluetun.containerConfig = {
              image = "docker.io/qmcgaw/gluetun:latest";
              pod = pods.torrent.ref;

              # Required by gluetun
              addCapabilities = [ "NET_ADMIN" ];

              devices = [ "/dev/net/tun:/dev/net/tun" ];
              podmanArgs = [ "--security-opt label=disable" ];

              environments = {
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
                "8000:8000" # Transferred from previous config, not sure why it's used
                "${cfg.gluetun.http-proxy-port}:8888"
                "${cfg.gluetun.shadowsocks-port}:8388/tcp"
                "${cfg.gluetun.shadowsocks-port}:8388/udp"
                "${cfg.qbittorrent.webui-port}:8080"
                "${cfg.prowlarr.port}:9696"
              ];
            };
          };
        };

      services.caddy =
        let
          domain = config.my-services.domain;
          FQDN = "${config.networking.hostName}.${domain}";
        in
        {
          enable = true;
          virtualHosts = {
            "http://torrents.${domain}".extraConfig = ''
              reverse_proxy http://${FQDN}:${cfg.qbittorrent.webui-port}
            '';
            "http://prowlarr.${domain}".extraConfig = ''
              reverse_proxy http://${FQDN}:${cfg.prowlarr.port}
            '';
          };
        };
    };
}
