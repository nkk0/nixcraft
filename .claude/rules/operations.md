# Operational Notes

## Plugin Runtime Configs

Plugins store runtime configs in `/var/lib/minecraft/plugins/<PluginName>/`. These are NOT managed by Nix.
To reload a plugin config without restarting: use RCON (e.g., `tab reload`, `lp reload`).
If RCON is unavailable, `mc-restart` is needed.

**CRITICAL**: When editing files in `/var/lib/minecraft/` as root, ALWAYS `chown minecraft:minecraft` afterward.
The hardened systemd service cannot chown files itself, and the preStart `chown -R` will fail, preventing server start.

## RCON Usage

Use the `mc-rcon` shell alias (available in interactive shells):
```bash
mc-rcon "say Hello"
mc-rcon "whitelist add PlayerName"
```

If `mc-rcon` isn't available (non-interactive shell), use the full `mcrcon` command with
the password from sops:
```bash
mcrcon -H 127.0.0.1 -P 25575 -p "$(cat /run/secrets/rcon-password)" "list"
```

## NixOS Module Gotchas

- `services.minecraft-server` requires `declarative = true` for `serverProperties` to take effect. Without it, Nix-defined properties are silently ignored.
- `nixos-rebuild switch` restarts affected services. Warn the server if players may be online.
- Plugin hash changes on version updates; use `nix-prefetch-url <url>` to get new hashes.
- TAB plugin animation `change-interval: 0` causes warnings; use at least 1000 or use static values directly.
