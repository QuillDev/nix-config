{ pkgs, inputs, ... }:

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
    fuzzel
    slack
    waybar
    mako
    wl-clipboard
    grim
    slurp
    hyprpaper
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
