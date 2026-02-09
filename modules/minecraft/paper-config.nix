{ config, lib, pkgs, ... }:

let
  cfg = config.services.minecraft-paper;
  format = pkgs.formats.yaml { };

  # Only override values that differ from Paper's defaults.
  # Unspecified values are managed by Paper itself, which keeps us
  # current with new defaults across version upgrades.

  paperGlobalConfig = format.generate "paper-global.yml" {
    _version = 29; # Paper config schema version — must match what Paper expects

    # Explicit thread/chunk tuning instead of auto-detection
    chunk-loading-advanced.player-max-chunk-load-rate = -1.0; # unlimited (default: 100)
    chunk-loading-basic = {
      player-max-concurrent-chunk-generates = 4; # default: auto
      player-max-concurrent-chunk-loads = 8; # default: auto
    };
    chunk-system = {
      io-threads = 4; # default: auto
      worker-threads = 4; # default: auto
    };

    messages = {
      # Suppress auth-server-down kick so players retry silently
      kick.authentication-servers-down = "";
      # Shorter, less apologetic permission denied message
      no-permission = "You do not have permission to perform this command.";
    };

    timings = {
      enabled = true; # default: false — needed for performance profiling
      server-name = cfg.serverName; # identify in Aikar's timings dashboard
    };
  };

  paperWorldConfig = format.generate "paper-world-defaults.yml" {
    _version = 31; # Paper config schema version

    anticheat.anti-xray = {
      enabled = true; # default: false — ore protection
      engine-mode = 1; # hide ores with stone
      hidden-blocks = [
        "copper_ore" "deepslate_copper_ore" "raw_copper_block"
        "gold_ore" "deepslate_gold_ore"
        "iron_ore" "deepslate_iron_ore" "raw_iron_block"
        "coal_ore" "deepslate_coal_ore"
        "lapis_ore" "deepslate_lapis_ore"
        "mossy_cobblestone" "obsidian" "chest"
        "diamond_ore" "deepslate_diamond_ore"
        "redstone_ore" "deepslate_redstone_ore"
        "clay" "emerald_ore" "deepslate_emerald_ore" "ender_chest"
      ];
    };

    # Prevent players from entering unloaded chunks (anti-exploit)
    chunks.prevent-moving-into-unloaded-chunks = true; # default: false

    # Fast despawn for common junk items (6000 ticks -> 300 ticks)
    entities.spawning.alt-item-despawn-rate = {
      enabled = true; # default: false
      items = {
        cobblestone = 300; netherrack = 300; sand = 300; red_sand = 300;
        gravel = 300; dirt = 300; short_grass = 300; pumpkin = 300;
        melon_slice = 300; kelp = 300; bamboo = 300; sugar_cane = 300;
        twisting_vines = 300; weeping_vines = 300; oak_leaves = 300;
        spruce_leaves = 300; birch_leaves = 300; jungle_leaves = 300;
        acacia_leaves = 300; dark_oak_leaves = 300; mangrove_leaves = 300;
        cactus = 300; diorite = 300; granite = 300; andesite = 300;
        scaffolding = 300;
      };
    };

    # Paper's optimized explosion algorithm
    environment.optimize-explosions = true; # default: false

    # Controlled by services.minecraft-paper.mobs.creeperGriefing
    mobs.creeper.allow-griefing = cfg.creeperGriefing;
  };

  spigotConfig = format.generate "spigot.yml" {
    # Exclude /skill from spam detection (Skript commands)
    commands.spam-exclusions = [ "/skill" ];

    world-settings.default = {
      # Prevent hoppers from loading chunks (performance)
      hopper-can-load-chunks = false; # default: true

      # Extended tracking ranges for better visibility (2x defaults)
      entity-tracking-range = {
        players = 128; # default: 48
        animals = 96; # default: 48
        monsters = 96; # default: 48
        misc = 64; # default: 32
      };

      # Wider activation range for raiders
      entity-activation-range.raiders = 64; # default: 48
    };
  };

  # bukkit.yml intentionally not managed — all values match Paper defaults.
  # Paper manages the file directly, keeping it current across updates.

  configFiles = [ paperGlobalConfig paperWorldConfig spigotConfig ];

in
{
  config = lib.mkIf cfg.enable {
    systemd.services.minecraft-server = {
      restartTriggers = configFiles;

      preStart = lib.mkAfter ''
        mkdir -p ${cfg.dataDir}/config

        cp -f ${paperGlobalConfig} ${cfg.dataDir}/config/paper-global.yml
        cp -f ${paperWorldConfig} ${cfg.dataDir}/config/paper-world-defaults.yml
        cp -f ${spigotConfig} ${cfg.dataDir}/spigot.yml

        chown -R minecraft:minecraft ${cfg.dataDir}/config
        chown minecraft:minecraft ${cfg.dataDir}/spigot.yml
      '';
    };
  };
}
