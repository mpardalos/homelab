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

  my-services = {
    domain = "home.mpardalos.com";
    datadir = "/data/data";
    container-env = {
      TZ = config.time.timeZone;
    };
    linuxserver-container-env = {
      PUID = "5000";
      PGID = "2000";
      UMASK = "002";
    };
    sonarr = {
      enable = true;
      port = "8989";
    };
    radarr = {
      enable = true;
      port = "7878";
    };
    jellyfin = {
      enable = true;
      port = "8096";
    };
    torrents = {
      enable = true;
      prowlarr.port = "9696";
      qbittorrent.webui-port = "8080";
      gluetun = {
        http-proxy-port = "8888";
        shadowsocks-port = "8388";
      };
    };
  };

  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  system.stateVersion = "24.11"; # Did you read the comment?
}
