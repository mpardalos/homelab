{ lib, config, ... }:
{
  options.my-services =
    with lib;
    with types;
    {
      settings = {
        datadir = mkOption { type = str; };
        reverse-proxy.enable = mkEnableOption "Reverse proxy";
        container-env = mkOption { type = attrsOf str; };
      };
      extra =
        let
          icon = attrTag {
            url = mkOption {
              description = "Image from a URL";
              type = str;
            };
            html = mkOption {
              description = "Custom html for icon";
              type = str;
            };
          };
          exposeOpts = submodule {
            options = {
              hostname = mkOption { type = str; };
              port = mkOption { type = port; };
            };
          };
          dashboardOpts = submodule {
            options = {
              icon = mkOption { type = icon; };
            };
          };
          service-definition = submodule {
            options = {
              expose = mkOption {
                type = nullOr exposeOpts;
                default = null;
              };
              dashboard = mkOption {
                type = nullOr dashboardOpts;
                default = null;
              };
              container = mkOption {
                type = nullOr (attrsOf anything);
                default = null;
              };
            };
          };
        in
        mkOption {
          type = attrsOf service-definition;
        };
    };
  config = {
    virtualisation = {
      containers.enable = true;
      podman.enable = true;
    };

    virtualisation.quadlet.containers =
      let
        mkContainer =
          name:
          { container, ... }:
          let
            extraEnv = if container ? extraEnv then container.extraEnv else { };
          in
          {
            containerConfig = {
              autoUpdate = "registry";
              environments = config.my-services.settings.container-env // extraEnv;
            } // (removeAttrs container [ "extraEnv" ]);
          };
      in
      lib.mapAttrs mkContainer (
        lib.filterAttrs (name: value: value.container != null) config.my-services.extra
      );

    networking.firewall.allowedTCPPorts = [
      80
      443
    ];

    services.caddy = {
      enable = true;
      virtualHosts = lib.mapAttrs' (
        name:
        { expose, ... }:
        {
          name = "http://${expose.hostname}";
          value.extraConfig = ''
            reverse_proxy http://localhost:${toString expose.port}
          '';
        }
      ) (lib.filterAttrs (_: value: value.expose != null) config.my-services.extra);
    };

    my-services.extra.olivetin.expose = {
      hostname = "buttons.home.mpardalos.com";
      port = 1337;
    };

    services.olivetin = {
      enable = true;
      settings.ListenAddressSingleHTTPFrontend = "0.0.0.0:${toString config.my-services.extra.olivetin.expose.port}";
      settings.actions =
        [
          {
            title = "Restart EVERYTHING";
            shell = "reboot";
            icon = ''<iconify-icon icon="ix:reboot" width="48" style="color: #ca2302"></iconify-icon>'';
          }
        ]
        ++ lib.mapAttrsToList (
          name:
          { dashboard, ... }:
          {
            title = "Restart ${name}";
            shell = "systemctl restart ${name}.service";
            timeout = 10;
            icon =
              let
                inherit (builtins) hasAttr;
              in
              if hasAttr "url" dashboard.icon then
                ''<img src = "${dashboard.icon.url}" width = "48px"/>''
              else if hasAttr "html" dashboard.icon then
                dashboard.icon.html
              else
                abort "Missing icon source";
          }
        ) (lib.filterAttrs (_: value: value.dashboard != null) config.my-services.extra);
    };
  };

}
