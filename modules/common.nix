{
  lib,
  ...
}:
{
  options.my-services = with lib; {
    domain = mkOption {
      type = types.str;
      description = "Domain the host belongs to. Hostname will be prepended to this (example: lab.example.com)";
      example = "example.com";
    };

    datadir = mkOption {
      type = types.str;
      description = "Location containing media (to be mounted as /data in containers)";
    };

    container-env = mkOption {
      type = types.attrsOf types.str;
      description = "Default env for all containers";
    };

    linuxserver-container-env = mkOption {
      type = types.attrsOf types.str;
      description = "Default env for linuxserver containers";
    };

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
}
