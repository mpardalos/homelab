{ config, lib, ... }:
{
  options.my-services.sonarr = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
    port = mkOption { type = types.port; };
  };
  config = lib.mkIf config.my-services.sonarr.enable {
    virtualisation = {
      containers.enable = true;
      podman.enable = true;
    };

    networking.firewall.allowedTCPPorts = [
      80
      443
    ];

    virtualisation.quadlet.containers = {
      sonarr.containerConfig = {
        image = "lscr.io/linuxserver/sonarr:latest";
        autoUpdate = "registry";
        publishPorts = [ "127.0.0.1:${toString config.my-services.sonarr.port}:8989" ];
        volumes = [
          "${config.my-services.datadir}:/data"
          "sonarr-config:/config"
        ];
        environments = config.my-services.container-env // config.my-services.linuxserver-container-env;
      };
    };

    services.caddy = {
      enable = true;
      virtualHosts."http://sonarr.${config.my-services.domain}".extraConfig = ''
        reverse_proxy http://localhost:${toString config.my-services.sonarr.port}
      '';
    };
  };
}
