{ ... }:

{
  networking.hostName = "respawned";

  boot.tmp.cleanOnBoot = true;
  zramSwap.enable = true;

  nixpkgs.config.allowUnfree = true;

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";

  # DO NOT CHANGE after initial install
  system.stateVersion = "23.11";
}
