# NixCraft - NixOS Minecraft Server

Paper MC server managed entirely through Nix.
Hostname: `respawned`. Single admin (OP level 4).

## Quick Reference

```bash
# Apply nix changes (RESTARTS affected services)
sudo nixos-rebuild switch --flake /etc/nixos#respawned

# Minecraft server management
mc-status          # systemctl status
mc-logs            # journalctl -f
mc-restart         # systemctl restart
mc-stop / mc-start # systemctl stop/start

# RCON - send commands to the running server WITHOUT restart
mc-rcon "say Hello"
mc-rcon "whitelist add PlayerName"
mc-rcon "op PlayerName"

# Backups (daily at 04:00 UTC, keeps last 10)
ls /var/lib/minecraft/backups/
systemctl start minecraft-backup  # trigger manual backup
```

## Architecture

```
/etc/nixos/
  flake.nix                         # Entry point, inputs (nixpkgs, sops-nix, pinned claude)
  configuration.nix                 # Top-level: imports modules, sets server options
  hardware-configuration.nix        # Auto-generated, do not edit
  .sops.yaml                        # Encryption rules (age public keys)
  secrets/respawned.yaml            # Encrypted secrets (safe to commit)
  modules/
    base.nix                        # Hostname, timezone, nix settings, gc
    ssh.nix                         # Hardened SSH, fail2ban, authorized keys
    sops.nix                        # sops-nix secret definitions
    packages.nix                    # System packages (mcrcon, claude-code, etc.)
    minecraft/
      default.nix                   # Custom module: options interface + systemd service
      plugins.nix                   # Plugin JARs with pinned sha256 hashes
      paper-config.nix              # Paper/Spigot config OVERRIDES (non-default values only)
```

Runtime data: `/var/lib/minecraft/` (world, plugins, backups, logs)

## RCON Policy

RCON is enabled and bound to localhost:25575. It is NOT exposed in the firewall.
Only Claude (running as root on this machine) should use it. **Never disable RCON** -
toggling it requires a server restart which disrupts players. Use RCON for:
- Whitelist/op management, broadcasting messages, running game commands
- Anything that doesn't require a nix config change

Use `nixos-rebuild switch` only when changing server configuration, plugins, or system packages.

## Nix Conventions (MUST follow)

- **Format**: 2-space indentation, `nixfmt-rfc-style` conventions
- **Module pattern**: Use `cfg = config.services.minecraft-paper;`, separate `options` from `config`, use `lib.mkIf cfg.enable { ... }`
- **No `rec` attrsets**: Use `let ... in` instead
- **No `with`**: Use `inherit` or explicit `pkgs.` prefix
- **Overrides only**: Config files (paper-config.nix) should only contain values that differ from upstream defaults. Comment each override with `# default: X` or a "why".
- **Submodule types**: Nested option groups use `lib.types.submodule`, not bare `{ ... }` nesting
- **Quote URLs**: Always quote string URLs in nix expressions
- **Keep `flake.nix` minimal**: Logic belongs in modules, not in the flake
- **Comments explain "why"**: Don't restate what the code does (e.g., no `# Hostname` above `networking.hostName`)
- **Pin dependencies**: All inputs pinned in flake.lock
- **No secrets in nix store**: Secrets are managed by sops-nix, decrypted to `/run/secrets/` at activation time. Never put plaintext secrets in Nix expressions.
- **`lib.mkDefault`** for baseline defaults, direct assignment for overrides, `lib.mkForce` sparingly
- **`lib.mkAfter`** for preStart scripts that must run after the main module's preStart

## Changing Plugins

Edit `/etc/nixos/modules/minecraft/plugins.nix`. Plugins use the `mkPlugin` helper — the attrset key is the JAR filename:
```nix
"PluginName.jar" = {
  url = "https://...";
  hash = "sha256-hash"; # use `nix-prefetch-url <url>` to get it
};
```

After editing, run `sudo nixos-rebuild switch --flake /etc/nixos#respawned`.
Plugins auto-deploy via preStart script. Server restarts on plugin changes.

## Changing Server Config

Paper/Spigot configs are in `paper-config.nix` — **only non-default overrides**, not full configs.
Bukkit.yml is not managed (all defaults). To add a new override, add the value with a `# default: X` comment.
Server properties are set via `configuration.nix` through `services.minecraft-paper` options.
The module interface (`default.nix`) exposes high-level options; add new ones following existing patterns.

## Network Ports

| Port  | Proto | Service               | Firewall |
|-------|-------|-----------------------|----------|
| 22    | TCP   | SSH (key-only)        | Open     |
| 25565 | TCP   | Minecraft (Java)      | Open     |
| 25575 | TCP   | RCON (localhost only) | Closed   |

## Security Policy (MUST follow)

**NixOS / System:**
- SSH is key-only (ed25519), root login via key only, fail2ban enabled. Never weaken these.
- Firewall is on by default. Only open ports explicitly listed in the Network Ports table above.
- Never expose new services to the internet without explicit approval from the admin.
- Never install packages or services that listen on public interfaces without discussion.
- Secrets managed by sops-nix (encrypted at rest, decrypted to tmpfs). Use `sops.secrets` for new secrets.
- The minecraft systemd service is hardened (NoNewPrivileges, ProtectSystem=strict, no capabilities). Do not weaken these protections.

**Minecraft:**
- `online-mode = true` - authenticates players via Mojang. Never disable this.
- Whitelist is enforced. Only add players when the admin requests it.
- Anti-Xray is enabled (engine-mode 1). Keep it on.
- Only the admin should be OP (level 4). Never grant OP to others without explicit approval.
- RCON is localhost-only and firewalled. Never bind it to 0.0.0.0 or open port 25575.
- Plugins: only install well-known, actively maintained plugins. Verify download URLs point to official sources (Hangar, Modrinth, GitHub releases, official project sites).

## Self-Improvement Rule

**Always update CLAUDE.md, `.claude/rules/`, and/or memory files when you:**
- Encounter an error, unexpected behavior, or learn something new
- Change the server architecture, add services, or modify conventions

## When Updating This File

Keep this file under 150 lines. Move detailed docs to `.claude/rules/` (auto-loaded).
