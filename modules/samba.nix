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
      media = {
        "path" = "${config.my.datadir}/media";
        "read only" = "no";
        "browseable" = "yes";
        "guest ok" = "yes";
        "force user" = "guest";
        "force group" = "media";
        "create mask" = "0664";
        "force create mode" = "0664";
        "directory mask" = "2775";
        "force directory mode" = "2775";
        "comment" = "Media library";
      };
    };
  };

  users.users.guest = {
    isNormalUser = true;
    extraGroups = [ "media" ];
  };
}
