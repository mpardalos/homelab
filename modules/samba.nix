{ config, lib, ... }:
{
  services.samba-wsdd = {
    enable = true;
    openFirewall = true;
  };

  services.samba = {
    enable = true;
    openFirewall = true;
    nmbd.enable = true;
    settings = {
      public = {
        "path" = config.my.datadir;
        "read only" = "no";
        "browseable" = "yes";
        "guest ok" = "yes";
        "create mask" = "0644";
        "directory mask" = "0755";
        "force user" = "guest";
        "comment" = "Public samba share.";
      };
    };
  };

  users.users.guest = {
    isNormalUser = true;
  };
}
