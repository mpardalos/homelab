{ config, lib, ... }:
{
  options.my-services.radarr = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
    port = mkOption { type = types.str; };
  };
  config = lib.mkIf config.my-services.sonarr.enable {
    virtualisation = {
      containers.enable = true;
      podman.enable = true;
    };

    virtualisation.quadlet.containers = {
      radarr.containerConfig = {
        image = "lscr.io/linuxserver/radarr:latest";
        autoUpdate = "registry";
        publishPorts = [ "${config.my-services.radarr.port}:7878" ];
        volumes = [
          "${config.my-services.datadir}:/data"
          "radarr-config:/config"
        ];
        environments = config.my-services.container-env // config.my-services.linuxserver-container-env;
      };
    };
    services.caddy =
      let
        domain = config.my-services.domain;
        FQDN = "${config.networking.hostName}.${domain}";
      in
      {
        enable = true;
        virtualHosts."http://radarr.${domain}".extraConfig = ''
          reverse_proxy http://${FQDN}:${config.my-services.radarr.port}
        '';
      };
  };
}
