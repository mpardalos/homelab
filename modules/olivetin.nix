{ config, lib, ... }:
{
  options.my-services.olivetin = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
    port = mkOption { type = types.port; };

    service-buttons = mkOption {
      type =
        with types;
        attrsOf (submodule {
          options = {
            serviceName = mkOption {
              description = "Systemd service name";
              type = str;
            };
            icon = mkOption {
              description = "Icon representing the service";
              type = attrTag {
                url = mkOption {
                  description = "Image from a URL";
                  type = str;
                };
                html = mkOption {
                  description = "Custom html for icon";
                  type = str;
                };
              };
            };
          };
        });
      default = { };
    };
  };
  config = lib.mkIf config.my-services.olivetin.enable {
    services.olivetin = {
      enable = true;
      settings.ListenAddressSingleHTTPFrontend = "0.0.0.0:${toString config.my-services.olivetin.port}";
      settings.actions =
        [
          {
            title = "Restart EVERYTHING";
            shell = "reboot";
            icon = ''<iconify-icon icon="ix:reboot" width="48" style="color: #ca2302"></iconify-icon>'';
          }
        ]
        ++ lib.map (
          { name, value }:
          {
            title = "Restart ${name}";
            shell = "systemctl restart ${value.serviceName}";
            timeout = 10;
            icon =
              let
                inherit (builtins) hasAttr;
              in
              if hasAttr "url" value.icon then
                ''<img src = "${value.icon.url}" width = "48px"/>''
              else if hasAttr "html" value.icon then
                value.icon.html
              else
                abort "Missing icon source";
          }
        ) (lib.attrsToList config.my-services.olivetin.service-buttons);
    };

    my-services.reverse-proxy.services = {
      buttons.port = config.my-services.olivetin.port;
    };
  };
}
