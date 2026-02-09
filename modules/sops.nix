{ ... }:

{
  sops = {
    defaultSopsFile = ../secrets/respawned.yaml;

    # Auto-detected from services.openssh.hostKeys (ed25519)
    # No need to set age.sshKeyPaths or age.keyFile

    secrets."rcon-password" = {
      owner = "minecraft";
      restartUnits = [ "minecraft-server.service" ];
    };
  };
}
