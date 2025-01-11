{ config, lib, ... }:
{
  options.my-services.jellyfin = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
    port = mkOption { type = types.port; };
  };
  config = lib.mkIf config.my-services.sonarr.enable (
    let
      jellyfin-url = "jellyfin.${config.my-services.domain}";
    in
    {
      virtualisation = {
        containers.enable = true;
        podman.enable = true;
      };

      networking.firewall.allowedTCPPorts = [
        80
        443
      ];

      virtualisation.quadlet.containers = {
        jellyfin.containerConfig = {
          image = "lscr.io/linuxserver/jellyfin:latest";
          autoUpdate = "registry";
          publishPorts = [ "${toString config.my-services.jellyfin.port}:8096" ];
          volumes = [
            "${config.my-services.datadir}:/data"
            "jellyfin-config:/config"
          ];
          devices = [
            "/dev/dri:/dev/dri"
          ];
          environments =
            config.my-services.container-env
            // config.my-services.linuxserver-container-env
            // {
              JELLYFIN_PublishedServerUrl = jellyfin-url;
              DOCKER_MODS = "linuxserver/mods:jellyfin-opencl-intel";
            };
        };
      };
      services.caddy = {
        enable = true;
        virtualHosts."http://${jellyfin-url}".extraConfig = ''
          reverse_proxy http://localhost:${toString config.my-services.jellyfin.port}
        '';
      };
    }
  );
}
