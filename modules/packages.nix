{ pkgs, inputs, ... }:

let
  # Latest fast-moving AI coding CLIs, sourced from nixos-unstable while the
  # rest of the system stays on the pinned stable channel.
  pkgs-unstable = import inputs.nixpkgs-unstable {
    inherit (pkgs.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };
  kimi-code = pkgs.callPackage ../pkgs/kimi-code { };
  pulumi-bin = pkgs.callPackage ../pkgs/pulumi-bin { };
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

    # Rust toolchain — qmenu and other local crates are built here regularly.
    # pkg-config + the native libs let `cargo build` find wayland/xkb/fontconfig
    # outside the qmenu dev shell.
    rustc
    cargo
    rustfmt
    clippy
    rust-analyzer
    pkg-config
    python3
    gnumake
    gcc
    nodejs
    pulumi-bin
    wayland
    libxkbcommon
    fontconfig
    freetype
    code-cursor-fhs
    discord
    adwaita-icon-theme
    # Papirus ships recoloured folder variants; `color` runs papirus-folders at
    # build time so the Papirus-Dark folders match the pink accent.
    (papirus-icon-theme.override { color = "pink"; })
    adwaita-qt
    gnome-themes-extra
    kdePackages.qt6ct
    libsForQt5.qt5ct
    tumbler
    ffmpegthumbnailer
    file-roller
    gvfs
    ghostty
    pkgs-unstable.codex
    pkgs-unstable.claude-code
    kimi-code
    jetbrains.datagrip
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
