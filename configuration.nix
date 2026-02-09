{ config, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./modules/base.nix
    ./modules/ssh.nix
    ./modules/packages.nix
    ./modules/sops.nix
    ./modules/minecraft
  ];

  services.minecraft-paper = {
    enable = true;
    serverName = "NixCraft";
    memory = "10G";
    viewDistance = 14;
    rcon = {
      enable = true;
      passwordFile = config.sops.secrets."rcon-password".path;
    };
  };

  # Port rules live in their respective modules
  networking.firewall.enable = true;
}
