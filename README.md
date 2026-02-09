# NixCraft

NixOS flake for a Paper Minecraft server.

## Structure

```
flake.nix                         # Entry point, inputs
configuration.nix                 # Top-level server options
modules/
  base.nix                        # Hostname, timezone, nix settings, GC
  ssh.nix                         # Hardened SSH, fail2ban
  sops.nix                        # sops-nix secret definitions
  packages.nix                    # System packages
  minecraft/
    default.nix                   # Custom module wrapping services.minecraft-server
    plugins.nix                   # Plugin JARs with pinned hashes
    paper-config.nix              # Paper/Spigot config overrides
```

## What's in here

- Custom `services.minecraft-paper` module with options for memory, view distance, RCON, mob control, backups, and systemd hardening
- Plugins pinned by URL + sha256, deployed via `preStart`
- Overrides-only configs (only non-default Paper/Spigot values, Paper manages the rest)
- Secrets via sops-nix (RCON password etc.)
- Daily backups with configurable retention
- Claude Code for AI-assisted server management over RCON

## Usage

Shared as a reference. To adapt for your own server:

1. Clone the repo
2. Replace `hardware-configuration.nix` with your own (`nixos-generate-config`)
3. Set up sops-nix, see [`secrets/README.md`](secrets/README.md)
4. Tweak `configuration.nix`
5. `sudo nixos-rebuild switch --flake .#respawned`

## License

[MIT](https://opensource.org/licenses/MIT)
