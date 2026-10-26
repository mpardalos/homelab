{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ../modules/common.nix
    ../modules/reverse-proxy.nix
    ../modules/nix.nix
    #####
    ../modules/startpage.nix
    ../modules/sonarr.nix
    ../modules/radarr.nix
    ../modules/jellyfin.nix
    ../modules/monitor.nix
    ../modules/donetick.nix
    ../modules/miniflux.nix
    ../modules/samba.nix
    ../modules/seer.nix
    ../modules/torrents.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixie";
  networking = {
    wireless.enable = lib.mkForce false;
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
    (pkgs.callPackage ../packages/scripts {})
  ];

  services.openssh.enable = true;
  services.tailscale.enable = true;

  networking.firewall.enable = true;

  fileSystems."/data" = {
    device = "/dev/disk/by-uuid/f2e7e959-0e92-46a0-b53f-9a4f3609d9fa";
    fsType = "btrfs";
  };

  virtualisation.quadlet.autoEscape = true;

  # Look into automatically managing CNAME records
  #   curl          forseti.home.mpardalos.com/api/config/dns/cnameRecords
  #   curl -XPUT    forseti.home.mpardalos.com/api/config/dns/cnameRecords/bloop.home.mpardalos.com,nixie.home.mpardalos.com
  #   curl -XDELETE forseti.home.mpardalos.com/api/config/dns/cnameRecords/bloop.home.mpardalos.com,nixie.home.mpardalos.com

  my = {
    datadir = "/data";
    domain = "home.mpardalos.com";
    container-env = {
      TZ = config.time.timeZone;
    };
    linuxserver-container-env = {
      PUID = "5000";
      PGID = "2000";
      UMASK = "002";
    };
  };

  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  system.stateVersion = "24.11"; # Did you read the comment?
}
