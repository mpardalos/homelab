{ config, lib, ... }:
{
  options.my-services.olivetin = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
    port = mkOption { type = types.port; };
  };
  config =
    let
      my-url = "http://buttons.${config.my-services.domain}";
    in
    lib.mkIf config.my-services.olivetin.enable {
      services.olivetin = {
        enable = true;
        settings.ListenAddressSingleHTTPFrontend = "0.0.0.0:${toString config.my-services.olivetin.port}";
        settings.actions = [
          {
            title = "Restart EVERYTHING";
            shell = "reboot";
            icon = ''<iconify-icon icon="ix:reboot" width="48" style="color: #ca2302"></iconify-icon>'';
          }
        ];
      };

      services.caddy = {
        enable = true;
        virtualHosts.${my-url}.extraConfig = ''
          reverse_proxy http://localhost:${toString config.my-services.olivetin.port}
        '';
      };
    };
}
