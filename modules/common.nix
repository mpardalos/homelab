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

    PUID = mkOption {
      type = types.str;
      description = "UID for linuxserver containers. See https://docs.linuxserver.io/general/understanding-puid-and-pgid/";
    };

    PGID = mkOption {
      type = types.str;
      description = "UID for linuxserver containers. See https://docs.linuxserver.io/general/understanding-puid-and-pgid/";
    };
  };
}
