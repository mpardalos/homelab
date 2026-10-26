{ config, lib, pkgs, ... }:
let
  php-user = config.services.caddy.user;
  php-group = config.services.caddy.group;
  url = "home.mpardalos.com";
  document-root = "/srv/homelab-startpage";
  live-files = "/home/mpardalos/homelab/startpage";
  systemctl = "${pkgs.systemd}/bin/systemctl";
in
{
  services.caddy.enable = true;

  # Serve the live checkout without exposing /home or changing its permissions.
  # Both Caddy's file checks and PHP-FPM must see the same document root.
  systemd.tmpfiles.rules = [ "d ${document-root} 0755 root root -" ];
  systemd.services.caddy.serviceConfig.BindReadOnlyPaths = [ "${live-files}:${document-root}" ];
  systemd.services.phpfpm-home-site.serviceConfig.BindReadOnlyPaths = [ "${live-files}:${document-root}" ];

  services.phpfpm.pools.home-site = {
    user = php-user;
    phpEnv = {
      HOMELAB_CONFIG = "/etc/service-inventory.json";
      PATH = "/run/wrappers/bin:/run/current-system/sw/bin";
    };
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
        { command = "${systemctl} --no-block reboot"; options = [ "NOPASSWD" ]; }
      ] ++ map (unit: {
        command = "${systemctl} restart ${unit}";
        options = [ "NOPASSWD" ];
      }) (lib.unique (map (svc: svc.serviceName) (builtins.attrValues config.my.services)));
    }
  ];
  users.users.${php-user}.extraGroups = [ "systemd-journal" ];

  services.caddy.virtualHosts.${url}.extraConfig = ''
      root * ${document-root}
      file_server
      php_fastcgi unix/${config.services.phpfpm.pools.home-site.socket}
    '';
}
