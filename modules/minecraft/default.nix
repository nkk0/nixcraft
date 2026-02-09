{ config, lib, pkgs, ... }:

let
  cfg = config.services.minecraft-paper;

  mkOpt = type: default: description: lib.mkOption { inherit type default description; };
  mkReq = type: description: lib.mkOption { inherit type description; };

  # Aikar's GC flags — tuned G1GC for Minecraft's allocation pattern to reduce
  # tick-stealing GC pauses. Standard for Paper servers (https://mcflags.emc.gs)
  jvmFlags = lib.concatStringsSep " " [
    "-Xms${cfg.memory}"
    "-Xmx${cfg.memory}"
    "-XX:+UseG1GC"
    "-XX:+ParallelRefProcEnabled"
    "-XX:MaxGCPauseMillis=200"
    "-XX:+UnlockExperimentalVMOptions"
    "-XX:+DisableExplicitGC"
    "-XX:+AlwaysPreTouch"
    "-XX:G1NewSizePercent=30"
    "-XX:G1MaxNewSizePercent=40"
    "-XX:G1HeapRegionSize=8M"
    "-XX:G1ReservePercent=20"
    "-XX:G1HeapWastePercent=5"
    "-XX:G1MixedGCCountTarget=4"
    "-XX:InitiatingHeapOccupancyPercent=15"
    "-XX:G1MixedGCLiveThresholdPercent=90"
    "-XX:G1RSetUpdatingPauseTimePercent=5"
    "-XX:SurvivorRatio=32"
    "-XX:+PerfDisableSharedMem"
    "-XX:MaxTenuringThreshold=1"
    "-Dusing.aikars.flags=https://mcflags.emc.gs"
    "-Daikars.new.flags=true"
  ];

  backupScript = pkgs.writeShellApplication {
    name = "minecraft-backup";
    runtimeInputs = [ pkgs.gnutar pkgs.coreutils pkgs.findutils ];
    text = ''
      BACKUP_DIR="${cfg.dataDir}/backups"
      mkdir -p "$BACKUP_DIR"
      cd "${cfg.dataDir}"

      TIMESTAMP=$(date +%Y%m%d_%H%M%S)
      tar -czf "$BACKUP_DIR/world_$TIMESTAMP.tar.gz" world world_nether world_the_end 2>/dev/null || true

      find "$BACKUP_DIR" -maxdepth 1 -name 'world_*.tar.gz' -type f -printf '%T@ %p\n' \
        | sort -rn \
        | tail -n +$((${toString cfg.backup.keep} + 1)) \
        | cut -d' ' -f2- \
        | xargs -r rm -f

      echo "Backup complete: world_$TIMESTAMP.tar.gz"
    '';
  };

in
{
  imports = [
    ./plugins.nix
    ./paper-config.nix
  ];

  options.services.minecraft-paper = {
    enable = lib.mkEnableOption "Paper Minecraft server";

    serverName = mkReq lib.types.str "The name of the Minecraft server.";
    memory = mkOpt lib.types.str "4G" "Memory allocation for the JVM (e.g. '4G', '8G').";
    dataDir = mkOpt lib.types.path "/var/lib/minecraft" "Directory where Minecraft server data is stored.";
    port = mkOpt lib.types.port 25565 "Port for the Java Edition server.";
    maxPlayers = mkOpt lib.types.int 20 "Maximum number of players.";
    viewDistance = mkOpt lib.types.int 10 "View distance in chunks.";
    simulationDistance = mkOpt lib.types.int 10 "Simulation distance in chunks.";
    whitelist = mkOpt lib.types.bool true "Whether to enable the whitelist.";
    creeperGriefing = mkOpt lib.types.bool false "Whether creeper explosions destroy blocks.";
    hardening = mkOpt lib.types.bool true "Whether to enable systemd service hardening.";
    motd = mkOpt lib.types.str "" "Message of the day (leave empty for auto-generated).";

    difficulty = mkOpt
      (lib.types.enum [ "peaceful" "easy" "normal" "hard" ]) "normal" "Game difficulty.";
    gamemode = mkOpt
      (lib.types.enum [ "survival" "creative" "adventure" "spectator" ]) "survival" "Default game mode.";

    package = lib.mkPackageOption pkgs.papermcServers "papermc" { };

    backup = lib.mkOption {
      type = lib.types.submodule {
        options = {
          enable = lib.mkEnableOption "automatic backups" // { default = true; };
          schedule = mkOpt lib.types.str "*-*-* 04:00:00" "Systemd calendar expression for backup schedule.";
          keep = mkOpt lib.types.int 10 "Number of backups to retain.";
        };
      };
      default = { };
      description = "World backup configuration.";
    };

    rcon = lib.mkOption {
      type = lib.types.submodule {
        options = {
          enable = lib.mkEnableOption "RCON remote console";
          port = mkOpt lib.types.port 25575 "Port for the RCON remote console.";
          passwordFile = mkOpt (lib.types.nullOr lib.types.path) null "Path to file containing the RCON password.";
        };
      };
      default = { };
      description = "RCON remote console configuration.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Auto-generate a colored motd from serverName unless explicitly set
    services.minecraft-paper.motd = lib.mkDefault
      "\\u00a7b\\u00a7l${cfg.serverName} \\u00a7r\\u00a77- \\u00a7aWelcome!";

    services.minecraft-server = {
      enable = true;
      declarative = true; # required — without this, serverProperties is silently ignored
      eula = true;
      package = cfg.package;
      dataDir = cfg.dataDir;
      openFirewall = true;

      whitelist = {
        # "PlayerName" = "uuid-here";
      };

      jvmOpts = jvmFlags;

      serverProperties = {
        server-name = cfg.serverName;
        motd = cfg.motd;
        server-port = cfg.port;
        max-players = cfg.maxPlayers;
        gamemode = cfg.gamemode;
        difficulty = cfg.difficulty;
        view-distance = cfg.viewDistance;
        simulation-distance = cfg.simulationDistance;

        white-list = cfg.whitelist;
        enforce-whitelist = cfg.whitelist; # kick players not on whitelist when it's reloaded
        online-mode = true; # authenticate via Mojang — never disable
        enable-command-block = true; # default: false
        spawn-protection = 20; # default: 16

        enable-rcon = cfg.rcon.enable;
        "rcon.port" = cfg.rcon.port;
        "rcon.password" =
          if cfg.rcon.passwordFile != null then "MANAGED_BY_SOPS"
          else "";
      };
    };

    # Substitute RCON password from sops secret into server.properties
    systemd.services.minecraft-server.preStart = lib.mkIf (cfg.rcon.passwordFile != null) (lib.mkAfter ''
      RCON_PASS=$(cat ${cfg.rcon.passwordFile})
      sed -i "s/^rcon\.password=.*/rcon.password=$RCON_PASS/" ${cfg.dataDir}/server.properties
    '');

    systemd.services.minecraft-server.serviceConfig = lib.mkIf cfg.hardening {
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      ReadWritePaths = [ cfg.dataDir ];
      NoNewPrivileges = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
      RestrictNamespaces = true;
      LockPersonality = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      RemoveIPC = true;
      CapabilityBoundingSet = [ "" ];
      AmbientCapabilities = [ "" ];
    };

    systemd.services.minecraft-backup = lib.mkIf cfg.backup.enable {
      description = "Backup Minecraft world";
      serviceConfig = {
        Type = "oneshot";
        User = "minecraft";
        Group = "minecraft";
        ExecStart = "${backupScript}/bin/minecraft-backup";
      };
    };

    systemd.timers.minecraft-backup = lib.mkIf cfg.backup.enable {
      description = "Periodic Minecraft backup";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.backup.schedule;
        Persistent = true;
      };
    };

    environment.shellAliases = {
      mc-logs = "journalctl -u minecraft-server -f";
      mc-status = "systemctl status minecraft-server";
      mc-restart = "systemctl restart minecraft-server";
      mc-stop = "systemctl stop minecraft-server";
      mc-start = "systemctl start minecraft-server";
    } // lib.optionalAttrs (cfg.rcon.passwordFile != null) {
      mc-rcon = ''mcrcon -H 127.0.0.1 -P ${toString cfg.rcon.port} -p "$(cat ${cfg.rcon.passwordFile})"'';
    };

    # Required by NixOS minecraft-server module for the server console
    environment.systemPackages = [ pkgs.screen ];
  };
}
