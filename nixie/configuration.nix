{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.my-services = with lib; {
    datadir = mkOption {
      type = types.str;
      description = "Location containing media (to be mounted as /data in containers)";
    };

    PUID = mkOption { type = types.str; };
    PGID = mkOption { type = types.str; };

    sonarr.port = mkOption { type = types.str; };
    radarr.port = mkOption { type = types.str; };
    jellyfin.port = mkOption { type = types.str; };
    prowlarr.port = mkOption { type = types.str; };
    qbittorrent.webui-port = mkOption { type = types.str; };
    gluetun = {
      http-proxy-port = mkOption { type = types.str; };
      shadowsocks-port = mkOption { type = types.str; };
    };
  };

  imports = [
    ./hardware-configuration.nix
  ];

  config = {
    nix = {
      gc.automatic = true;
      settings.experimental-features = [
        "nix-command"
        "flakes"
      ];
      settings.trusted-users = [
        "root"
        "@wheel"
      ];
    };

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;

    networking.hostName = "nixie";
    networking = {
      wireless.enable = false;
      networkmanager.enable = true;
    };

    time.timeZone = "Europe/London";

    users.users.mpardalos = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
    };

    environment.systemPackages = with pkgs; [
      vim
      wget
    ];

    services.openssh.enable = true;

    networking.firewall.enable = false;

    fileSystems."/data" = {
      device = "/dev/disk/by-uuid/f2e7e959-0e92-46a0-b53f-9a4f3609d9fa";
      fsType = "btrfs";
    };

    virtualisation = {
      containers.enable = true;
      podman = {
        enable = true;
        dockerCompat = true;
        defaultNetwork.settings.dns_enabled = true;
      };
    };

    my-services = {
      datadir = "/data/data";
      PUID = "5000";
      PGID = "2000";
      sonarr.port = "8989";
      radarr.port = "7878";
      jellyfin.port = "8096";
      prowlarr.port = "9696";
      qbittorrent.webui-port = "8080";
      gluetun = {
        http-proxy-port = "8888";
        shadowsocks-port = "8388";
      };
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
          sonarr.containerConfig = {
            image = "lscr.io/linuxserver/sonarr:latest";
            autoUpdate = "registry";
            publishPorts = [ "${config.my-services.sonarr.port}:8989" ];
            volumes = [
              "${config.my-services.datadir}:/data"
              "sonarr-config:/config"
            ];
            environments = usualEnv;
          };
          radarr.containerConfig = {
            image = "lscr.io/linuxserver/radarr:latest";
            autoUpdate = "registry";
            publishPorts = [ "${config.my-services.radarr.port}:7878" ];
            volumes = [
              "${config.my-services.datadir}:/data"
              "radarr-config:/config"
            ];
            environments = usualEnv;
          };
          jellyfin.containerConfig = {
            image = "lscr.io/linuxserver/jellyfin:latest";
            autoUpdate = "registry";
            publishPorts = [ "${config.my-services.jellyfin.port}:8096" ];
            volumes = [
              "${config.my-services.datadir}:/data"
              "jellyfin-config:/config"
            ];
            devices = [
              "/dev/dri:/dev/dri"
            ];
            environments = usualEnv // {
              JELLYFIN_PublishedServerUrl = "jellyfin.home.mpardalos.com";
              DOCKER_MODS = "linuxserver/mods:jellyfin-opencl-intel";
            };
          };
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
              "${config.my-services.datadir}:/data"
              "qbittorrent-config:/config"
            ];
            pod = pods.torrent.ref;
            environments = usualEnv // {
              WEBUI_PORT = "${config.my-services.qbittorrent.webui-port}";
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
              "8000:8000"
              "${config.my-services.gluetun.http-proxy-port}:8888"
              "${config.my-services.gluetun.shadowsocks-port}:8388/tcp"
              "${config.my-services.gluetun.shadowsocks-port}:8388/udp"
              "${config.my-services.qbittorrent.webui-port}:8080"
              "${config.my-services.prowlarr.port}:9696"
            ];
          };
        };
      };

    services.caddy = {
      enable = true;
      extraConfig =
        let
          myFQDN = "${config.networking.hostName}.home.mpardalos.com";
        in
        ''
          http://sonarr.home.mpardalos.com { reverse_proxy http://${myFQDN}:${config.my-services.sonarr.port} }
          http://radarr.home.mpardalos.com { reverse_proxy http://${myFQDN}:${config.my-services.radarr.port} }
          http://torrents.home.mpardalos.com { reverse_proxy http://${myFQDN}:${config.my-services.qbittorrent.webui-port} }
          http://prowlarr.home.mpardalos.com { reverse_proxy http://${myFQDN}:${config.my-services.prowlarr.port} }
          http://jellyfin.home.mpardalos.com { reverse_proxy http://${myFQDN}:${config.my-services.jellyfin.port} }
        '';
    };

    # Most users should NEVER change this value after the initial install, for any reason,
    # even if you've upgraded your system to a new NixOS release.
    system.stateVersion = "24.11"; # Did you read the comment?
  };

}
