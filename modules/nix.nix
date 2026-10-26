{
  nix = {
    gc.automatic = true;
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
    settings.trusted-users = [
      "root"
      "@wheel"
    ];
  };

  programs.nh = {
    enable = true;
    flake = "/home/mpardalos/homelab";
  };
}
