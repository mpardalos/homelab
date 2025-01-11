{ config, lib, ... }:
{
  options.my-services.radarr = with lib; {
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
      radarr.containerConfig = {
        image = "lscr.io/linuxserver/radarr:latest";
        autoUpdate = "registry";
        publishPorts = [ "${toString config.my-services.radarr.port}:7878" ];
        volumes = [
          "${config.my-services.datadir}:/data"
          "radarr-config:/config"
        ];
        environments = config.my-services.container-env // config.my-services.linuxserver-container-env;
      };
    };
    services.caddy = {
      enable = true;
      virtualHosts."http://radarr.${config.my-services.domain}".extraConfig = ''
        reverse_proxy http://localhost:${toString config.my-services.radarr.port}
      '';
    };
  };
}
