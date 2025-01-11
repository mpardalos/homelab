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
    packages = with pkgs; [ ];
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

  virtualisation.quadlet =
    let
      usualEnv = {
        PUID = "5000";
        PGID = "2000";
        UMASK = "002";
        TZ = "Europe/London";
      };

      inherit (config.virtualisation.quadlet) networks pods;
    in
    {
      containers = {
        sonarr.containerConfig = {
          image = "lscr.io/linuxserver/sonarr:latest";
          autoUpdate = "registry";
          publishPorts = [ "8989:8989" ];
          volumes = [
            "/data/data:/data"
            "sonarr-config:/config"
          ];
          environments = usualEnv;
        };
        radarr.containerConfig = {
          image = "lscr.io/linuxserver/radarr:latest";
          autoUpdate = "registry";
          publishPorts = [ "7878:7878" ];
          volumes = [
            "/data/data:/data"
            "radarr-config:/config"
          ];
          environments = usualEnv;
        };
        jellyfin.containerConfig = {
          image = "lscr.io/linuxserver/jellyfin:latest";
          autoUpdate = "registry";
          publishPorts = [ "8096:8096" ];
          volumes = [
            "/data/data:/data"
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
            "/data/data:/data"
            "qbittorrent-config:/config"
          ];
          pod = pods.torrent.ref;
          environments = usualEnv // {
            WEBUI_PORT = "8080";
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
      pods = {
        torrent.podConfig = {
          publishPorts = [
            "8000:8000"
            "8888:8888"
            "8388:8388/tcp"
            "8388:8388/udp"
            "8080:8080"
            "9696:9696"
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
        http://sonarr.home.mpardalos.com { reverse_proxy http://${myFQDN}:8989 }
        http://radarr.home.mpardalos.com { reverse_proxy http://${myFQDN}:7878 }
        http://torrents.home.mpardalos.com { reverse_proxy http://${myFQDN}:8080 }
        http://prowlarr.home.mpardalos.com { reverse_proxy http://${myFQDN}:9696 }
        http://actions.home.mpardalos.com { reverse_proxy http://${myFQDN}:1337 }
        http://gerbera.home.mpardalos.com { reverse_proxy http://${myFQDN}:49494 }
        http://jellyfin.home.mpardalos.com { reverse_proxy http://${myFQDN}:8096 }
      '';
  };

  services.technitium-dns-server.enable = true;

  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  system.stateVersion = "24.11"; # Did you read the comment?

}
