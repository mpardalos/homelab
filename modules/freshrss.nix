{ config, lib, ... }:
{
  options.my-services.freshrss = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
    port = mkOption { type = types.port; };
  };
  config = lib.mkIf config.my-services.freshrss.enable {
    virtualisation = {
      containers.enable = true;
      podman.enable = true;
    };

    networking.firewall.allowedTCPPorts = [
      80
      443
    ];

    virtualisation.quadlet.containers = {
      freshrss.containerConfig = {
        image = "lscr.io/linuxserver/freshrss:latest";
        autoUpdate = "registry";
        publishPorts = [ "127.0.0.1:${toString config.my-services.freshrss.port}:80" ];
        volumes = [
          "freshrss-config:/config"
        ];
        environments = config.my-services.container-env // config.my-services.linuxserver-container-env;
      };
    };

    services.caddy = {
      enable = true;
      virtualHosts."http://freshrss.${config.my-services.domain}".extraConfig = ''
        reverse_proxy http://localhost:${toString config.my-services.freshrss.port}
      '';
    };
  };
}
