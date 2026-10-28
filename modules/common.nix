{
  config,
  pkgs,
  lib,
  ...
}:
{
  options.my = with lib; {
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

    services = mkOption {
      type =
        with types;
        attrsOf (submodule ({ name, ... }: {
          options = {
            name = mkOption {
              description = "Label displayed on the startpage";
              type = str;
              default = lib.strings.toSentenceCase name;
            };
            port = mkOption {
              type = port;
            };
            order = mkOption {
              description = "Position on the startpage; lower values come first";
              type = int;
              default = 100;
            };
            serviceName = mkOption {
              description = "Systemd service name";
              type = strMatching "[a-zA-Z0-9_@.:-]+[.]service";
              default = "${name}.service";
            };
            icon = mkOption {
              description = "Icon representing the service";
              default = null;
              type = nullOr (attrTag {
                url = mkOption {
                  description = "Full URL of the image";
                  type = str;
                };
                path = mkOption {
                  description = "Path to the image relative to the domain it's served at";
                  type = str;
                  example = "icons/favicon.png";
                };
              });
            };
          };
        }));
      default = { };
    };
  };

  config = {
    assertions = [ {
      assertion = lib.all (name: name != "server" && builtins.match "[a-zA-Z0-9_-]+" name != null) (builtins.attrNames config.my.services);
      message = "Startpage service button IDs must contain only letters, numbers, underscores or hyphens, and cannot be 'server'.";
    } ];

  };
}
