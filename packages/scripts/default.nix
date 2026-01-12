{ pkgs }:

pkgs.stdenv.mkDerivation {
  pname = "homelab-scripts";
  version = "0.1.0";

  src = ./.;

  nativeBuildInputs = [ pkgs.makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin

    # Install telegram-notify with wrapper
    cp telegram-notify $out/bin/telegram-notify
    chmod +x $out/bin/telegram-notify
    wrapProgram $out/bin/telegram-notify \
      --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.curl pkgs.coreutils ]}

    # Install monitor with wrapper (needs telegram-notify in PATH)
    cp monitor $out/bin/monitor
    chmod +x $out/bin/monitor
    wrapProgram $out/bin/monitor \
      --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.util-linux pkgs.coreutils ]}:$out/bin
  '';

  meta = {
    description = "Homelab monitoring and notification scripts";
  };
}
