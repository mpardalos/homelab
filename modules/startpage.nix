{ config, lib, pkgs, ... }:

let
  cfg = config.my-services.startpage;
  php-user = config.services.caddy.user;
  php-group = config.services.caddy.group;
in {
  options.my-services.startpage = with lib; {
    enable = mkEnableOption "Custom startpage";
    url = mkOption { type = types.str; };
    files-dir = mkOption {
      type = types.path;
      description = "Path to directory containing the .php files for the site";
    };
  };

  config = lib.mkIf cfg.enable {
    services.caddy.enable = true;

    services.phpfpm.pools.home-site = {
      user = php-user;
      settings = {
        "listen.owner" = php-user;
        "listen.group" = php-group;
        "pm" = "dynamic";
        "pm.max_children" = 5;
        "pm.start_servers" = 2;
        "pm.min_spare_servers" = 1;
        "pm.max_spare_servers" = 3;

        # Send output to syslog
        "catch_workers_output" = "yes";
        "php_admin_flag[log_errors]" = "on";
        "php_admin_value[error_log]" = "syslog";
      };
    };

    security.sudo.extraRules = [
      {
        users = [ php-user ];
        commands = [
          { command = "/run/current-system/sw/bin/systemctl restart jellyfin.service"; options = [ "NOPASSWD" ]; }
          { command = "/run/current-system/sw/bin/systemctl restart transmission.service"; options = [ "NOPASSWD" ]; }
          { command = "/run/current-system/sw/bin/systemctl restart sonarr.service"; options = [ "NOPASSWD" ]; }
          { command = "/run/current-system/sw/bin/systemctl restart radarr.service"; options = [ "NOPASSWD" ]; }
        ];
      }
    ];
    users.users.${php-user}.extraGroups = [ "systemd-journal" ];

    services.caddy.virtualHosts."http://${cfg.url}".extraConfig = ''
      root * ${cfg.files-dir}
      file_server
      php_fastcgi unix/${config.services.phpfpm.pools.home-site.socket}
    '';
  };
}
