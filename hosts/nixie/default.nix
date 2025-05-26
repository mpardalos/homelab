{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
  ];

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
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKVsAwlpLoXVkLgCaGHHkSJrrEk7zsnfR3e+9ZbJDCwz mpardalos@odin"
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC0pYgj0FmRWjLuOOXu20/aguNWe8Q7bg7jky95HoN6fI1optrsHVlR7iEqB3g6BCBSSBjIxVEsymf3Z0iXaPAf9Y60aUXXQrnEfATcSVn2akBiBkCp8vq/k06hrTavPDbF7BUQaV9VcrTMTEnVbHPzpOCW3wcItQ3j3bvWxBMZicYoMyK3oEnUMLOWLYFaYGTj5cfJD5x8OW8QCvLgYNMa7TATfULvTUjU4RCXpFrRs92lDoo4zwPKzTlF9ie8YDagjZdLmLdrg8nM5duITeOVEXFJ/5DAeUrebuHWR9XiCp0sFUzxxSovMTSW8kglGDNU5GVw1VxPQmgJfnPOVUoJo3v4ZJJxVHGsTFh1M+FHLF2dAB4wks37MkRpd3v8AwkW5DAjEU6MR+CguxpAW+zH+eqJ5Gvus3Jigw3ptHYuAmgZ4tW8mC3AxmZCxN2dBAZlIN6Ub+gM7S4vMClOHxs1oJOYmJUUsuEcxc3u/iTjJjR5HAppCwFHugi5AZBGWJ0= mpardalos@magni"
    ];
  };

  environment.systemPackages = with pkgs; [
    vim
    wget
  ];

  services.openssh.enable = true;

  networking.firewall.enable = true;

  fileSystems."/data" = {
    device = "/dev/disk/by-uuid/f2e7e959-0e92-46a0-b53f-9a4f3609d9fa";
    fsType = "btrfs";
  };

  my-services.settings = {
    datadir = "/data/data";
    reverse-proxy.enable = true;
    container-env = {
      TZ = config.time.timeZone;
      # For linuxserver/hotio containers. They shouldn't hurt for other
      # containers, so just use them for everything
      PUID = "5000";
      PGID = "2000";
      UMASK = "002";
    };
  };

  my-services.extra = {
    sonarr = rec {
      expose = {
        hostname = "sonarr.home.mpardalos.com";
        port = 8989;
      };
      dashboard.icon.url = "${expose.hostname}/favicon.ico";
      container = {
        image = "lscr.io/linuxserver/sonarr:latest";
        publishPorts = [
          "127.0.0.1:${toString expose.port}:8989"
        ];
        volumes = [
          "${config.my-services.settings.datadir}:/data"
          "sonarr-config:/config"
        ];
      };
    };

    radarr = rec {
      expose = {
        hostname = "radarr.home.mpardalos.com";
        port = 7878;
      };
      dashboard.icon.url = "${expose.hostname}/favicon.ico";
      container = {
        image = "lscr.io/linuxserver/radarr:latest";
        publishPorts = [
          "127.0.0.1:${toString expose.port}:7878"
        ];
        volumes = [
          "${config.my-services.settings.datadir}:/data"
          "radarr-config:/config"
        ];
      };
    };

    jellyfin = rec {
      expose = {
        hostname = "jellyfin.home.mpardalos.com";
        port = 8096;
      };
      dashboard.icon.url = "${expose.hostname}/favicon.ico";
      container = {
        image = "lscr.io/linuxserver/jellyfin:latest";
        publishPorts = [
          "127.0.0.1:${toString expose.port}:8096"
        ];
        volumes = [
          "${config.my-services.settings.datadir}:/data"
          "jellyfin-config:/config"
        ];
        devices = [
          "/dev/dri:/dev/dri"
        ];
        extraEnv = {
          JELLYFIN_PublishedServerUrl = expose.hostname;
          DOCKER_MODS = "linuxserver/mods:jellyfin-opencl-intel";
        };
      };
    };

    ersatztv = rec {
      expose = {
        hostname = "ersatztv.home.mpardalos.com";
        port = 8409;
      };
      dashboard.icon.url = "${expose.hostname}/favicon.ico";
      container = {
        image = "docker.io/jasongdove/ersatztv:latest-vaapi";
        publishPorts = [ "127.0.0.1:${toString expose.port}:8409" ];
        devices = [ "/dev/dri:/dev/dri" ];
        volumes = [
          "${config.my-services.settings.datadir}:/data"
          "ersatztv-config:/config"
        ];
      };
    };

    prowlarr =
      let
        inherit (config.virtualisation.quadlet) pods;
      in
      rec {
        expose = {
          hostname = "prowlarr.home.mpardalos.com";
          port = 9696;
        };
        dashboard.icon.url = "${expose.hostname}/favicon.ico";
        container = {
          image = "lscr.io/linuxserver/prowlarr:latest";
          volumes = [ "prowlarr-config:/config" ];
          # Ports exposed by pod
          pod = pods.torrent.ref;
        };
      };

    qbittorrent =
      let
        inherit (config.virtualisation.quadlet) pods;
      in
      rec {
        expose = {
          hostname = "torrents.home.mpardalos.com";
          port = 8080;
        };
        dashboard.icon.url = "${expose.hostname}/images/qbittorrent-tray.svg";
        container = {
          image = "lscr.io/linuxserver/qbittorrent:latest";
          volumes = [
            "${config.my-services.settings.datadir}:/data"
            "qbittorrent-config:/config"
          ];
          # Ports exposed by pod
          pod = pods.torrent.ref;
          environments = {
            WEBUI_PORT = "8080";
          };
        };
      };

    gluetun =
      let
        inherit (config.virtualisation.quadlet) pods;
      in
      rec {
        dashboard.icon.html = ''<iconify-icon icon="flat-color-icons:lock" width="48"></iconify-icon>'';
        container = {
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
            WIREGUARD_PRIVATE_KEY = "'uJr8vz2+AjKGEuOd8P1bCcx7fouHmfWpeygUeu4t40U='";
            WIREGUARD_PRESHARED_KEY = "'RThO0ecGpNfvaInJCBEvHuR9vXY+8zdVLvYfjKDYrqI='";
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

  };

  virtualisation.quadlet.pods.torrent.podConfig = {
    publishPorts = [
      # Gluetun HTTP Proxy
      "0.0.0.0:8888:8888"
      # Gluetun Shadowsocks
      "0.0.0.0:8388:8388/tcp"
      "0.0.0.0:8388:8388/udp"
      # qBittorrent WebUI
      "127.0.0.1:${toString config.my-services.extra.qbittorrent.expose.port}:8080"
      # Prowlarr
      "127.0.0.1:${toString config.my-services.extra.prowlarr.expose.port}:9696"
    ];
  };

  # Gluetun
  networking.firewall.allowedTCPPorts = [
    8888
    8388
  ];
  networking.firewall.allowedUDPPorts = [ 8388 ];

  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  system.stateVersion = "24.11"; # Did you read the comment?
}
