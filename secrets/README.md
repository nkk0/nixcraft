# Secrets (not tracked)

This directory contains sops-encrypted secrets, decrypted at activation time by
[sops-nix](https://github.com/Mic92/sops-nix) to `/run/secrets/`.

To use this config, create `.sops.yaml` in the repo root and `secrets/respawned.yaml`
encrypted with your own age/GPG keys. Required secrets:

- `rcon-password`: RCON password for localhost server management
