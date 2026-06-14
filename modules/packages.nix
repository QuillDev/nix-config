{ pkgs, inputs, ... }:

let
  # Latest fast-moving AI coding CLIs, sourced from nixos-unstable while the
  # rest of the system stays on the pinned stable channel.
  pkgs-unstable = import inputs.nixpkgs-unstable {
    inherit (pkgs.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };
  kimi-code = pkgs.callPackage ../pkgs/kimi-code { };
in

{
  nixpkgs.config.allowUnfree = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  environment.systemPackages = with pkgs; [
    vim
    wget
    git
    gh
    ripgrep
    bun
    code-cursor-fhs
    discord
    adwaita-icon-theme
    adwaita-qt
    gnome-themes-extra
    ghostty
    pkgs-unstable.codex
    pkgs-unstable.claude-code
    kimi-code
    fuzzel
    walker
    elephant
    slack
    ashell
    mako
    libnotify
    brightnessctl
    wl-clipboard
    grim
    slurp
    hyprpaper
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
