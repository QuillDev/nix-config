{ pkgs, ... }:

{
  services.xserver.enable = true;

  services.displayManager.sddm.enable = true;
  services.displayManager.defaultSession = "hyprland";
  services.desktopManager.plasma6.enable = true;
  environment.plasma6.excludePackages = with pkgs.kdePackages; [
    dolphin
    dolphin-plugins
  ];

  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
  };

  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  services.printing.enable = true;

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  programs.dconf.enable = true;

  # Use the NixOS Thunar module rather than a bare package so that
  # programs.xfconf is enabled and Thunar settings (e.g. disabling the 4.20
  # file-highlight feature) actually persist via xfconfd.
  programs.thunar = {
    enable = true;
    plugins = with pkgs; [
      thunar-archive-plugin
      thunar-volman
    ];
  };

  services.gvfs.enable = true;
  services.tumbler.enable = true;

  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-hyprland
    ];
    config.common.default = [
      "hyprland"
      "gtk"
    ];
  };

  fonts.packages = with pkgs; [
    inter
    # Glyph fallback so the ashell agent-usage chip can render a Nerd Font icon
    # (Inter has no such glyph; fontconfig falls back to this).
    nerd-fonts.symbols-only
  ];

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    GTK_THEME = "Adwaita:dark";
    QT_QPA_PLATFORMTHEME = "qt6ct";
    XDG_CURRENT_DESKTOP = "Hyprland";
    XDG_SESSION_DESKTOP = "Hyprland";
  };
}
