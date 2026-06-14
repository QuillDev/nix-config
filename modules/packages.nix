{ pkgs, inputs, ... }:

let
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
    codex
    claude-code
    kimi-code
    fuzzel
    slack
    ashell
    mako
    libnotify
    wl-clipboard
    grim
    slurp
    hyprpaper
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
