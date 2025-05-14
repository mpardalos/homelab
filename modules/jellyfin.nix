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
      my-url = "http://jellyfin.${config.my-services.domain}";
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
          publishPorts = [ "127.0.0.1:${toString config.my-services.jellyfin.port}:8096" ];
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
              JELLYFIN_PublishedServerUrl = my-url;
              DOCKER_MODS = "linuxserver/mods:jellyfin-opencl-intel";
            };
        };
      };

      services.caddy = {
        enable = true;
        virtualHosts.${my-url}.extraConfig = ''
          reverse_proxy http://localhost:${toString config.my-services.jellyfin.port}
        '';
      };

      services.olivetin.settings.actions = [
        {
          title = "Restart jellyfin";
          shell = "systemctl restart jellyfin.service";
          timeout = 10;
          icon = ''<img src = "${my-url}/web/favicon.png" width = "48px"/>'';
        }
      ];
    }
  );
}
