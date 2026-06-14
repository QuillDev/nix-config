{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/a0374025a863d007d98e3297f6aa46cc3141c2f0";

    # Tracks latest releases of fast-moving AI coding CLIs (claude-code, codex).
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Rolling: tracks the qmenu repo's main branch, bumped via `nix flake update`.
    qmenu = {
      url = "github:QuillDev/qmenu";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Rolling: AI coding-agent usage limits for the ashell bar. Bumped via
    # `nix flake update agent-usage`.
    agent-usage = {
      url = "github:QuillDev/agent-usage";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ nixpkgs, home-manager, ... }: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        ./configuration.nix
        home-manager.nixosModules.home-manager
      ];
    };
  };
}
