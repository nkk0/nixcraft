{
  description = "NixCraft Minecraft Server";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Pinned nixpkgs for claude-code 2.1.34 (not yet in CI-passed unstable)
    nixpkgs-claude.url = "github:NixOS/nixpkgs/e0eaf9d78f39b1ea7f4cca30e6e47ac4fc13a24f";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-claude, sops-nix, ... } @ inputs: {
    nixosConfigurations.respawned = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };

      modules = [
        ./configuration.nix
        sops-nix.nixosModules.sops
        # Overlay: use claude-code from pinned nixpkgs
        ({ ... }: {
          nixpkgs.overlays = [
            (final: prev: {
              claude-code = (import nixpkgs-claude {
                system = "x86_64-linux";
                config = { allowUnfree = true; };
              }).claude-code;
            })
          ];
        })
      ];
    };
  };
}
