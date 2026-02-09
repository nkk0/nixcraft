{ config, lib, pkgs, ... }:

let
  cfg = config.services.minecraft-paper;
  pluginsDir = "${cfg.dataDir}/plugins";

  mkPlugin = name: { url, hash }:
    pkgs.fetchurl { inherit url name; sha256 = hash; };

  plugins = lib.mapAttrs mkPlugin {
    # Version compatibility
    "ViaVersion.jar" = {
      url = "https://hangar.papermc.io/api/v1/projects/ViaVersion/versions/5.7.1/PAPER/download";
      hash = "0nm9gvpd3b7ijv63jcjnln6icxip1818p782dwif9cvm7i2drlhc";
    };
    "ViaBackwards.jar" = {
      url = "https://hangar.papermc.io/api/v1/projects/ViaBackwards/versions/5.7.1/PAPER/download";
      hash = "1j5hj4gnpln0nhf9ihnzb7qll8d008v5f61s5wn1775cv2vamhy2";
    };

    # Permissions
    "LuckPerms-Bukkit.jar" = {
      url = "https://ci.lucko.me/job/LuckPerms/lastSuccessfulBuild/artifact/bukkit/loader/build/libs/LuckPerms-Bukkit-5.5.32.jar";
      hash = "1xvzy0mhv5s64283sdkanndwn64ml60nf0fjry1x4ijwk4fiw2fh";
    };

    # World management
    "Chunky.jar" = {
      url = "https://hangar.papermc.io/api/v1/projects/Chunky/versions/1.4.40/PAPER/download";
      hash = "08cpq11i83rc949b33dj4dvf2dmqpr6y676ybbhi447ph3y7fm1a";
    };

    # Player experience
    "HuskHomes.jar" = {
      url = "https://hangar.papermc.io/api/v1/projects/HuskHomes/versions/4.9.10/PAPER/download";
      hash = "09m3q5mps7sxn0i4i71h5mjdv86aliy00i3aiiq7q55zqhlh2r56";
    };
    "TAB.jar" = {
      url = "https://github.com/NEZNAMY/TAB/releases/download/5.5.0/TAB.v5.5.0.jar";
      hash = "1xk5x9m1gnj0y567mcy5r5wsadd3wj7rlisk7gcnj4645g17x7l2";
    };

    # Scripting (used for chat filters)
    "Skript.jar" = {
      url = "https://github.com/SkriptLang/Skript/releases/download/2.14.1/Skript-2.14.1.jar";
      hash = "0vbcxlzby90gqcvsady7dca1qvqnqr19cbqzsgxfjys1m662bl8d";
    };
  };

  allPlugins = lib.attrValues plugins;

in
{
  config = lib.mkIf cfg.enable {
    systemd.services.minecraft-server = {
      restartTriggers = allPlugins;

      preStart = lib.mkAfter ''
        mkdir -p ${pluginsDir}

        ${lib.concatStringsSep "\n" (lib.mapAttrsToList (_: plugin: ''
          cp -f ${plugin} ${pluginsDir}/${plugin.name}
        '') plugins)}

        chown -R minecraft:minecraft ${pluginsDir}
      '';
    };
  };
}
