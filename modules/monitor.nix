{ config, lib, pkgs, ... }:
let
  homelab-scripts = pkgs.callPackage ../packages/scripts {};
in
{
  options.my-services.monitor.enable = lib.mkEnableOption "Data drive mount monitor";

  config = lib.mkIf config.my-services.monitor.enable {
    systemd.services.data-mount-monitor = {
      description = "Monitor /data mount point and notify on disconnection";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      # Add required binaries to PATH
      path = [ homelab-scripts ];

      serviceConfig = {
        Type = "simple";
        Restart = "always";
        RestartSec = "10s";
        EnvironmentFile = "/etc/telegram-notify.env";
        ExecStart = "${homelab-scripts}/bin/monitor";
        Environment = [ "STATE_FILE=%S/data-mount-monitor/mount_state" ];

        # Security hardening
        DynamicUser = true;
        StateDirectory = "data-mount-monitor";
      };
    };
  };
}
