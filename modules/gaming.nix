{ pkgs, ... }:

let
  stardrop = pkgs.callPackage ../pkgs/stardrop { };
in

{
  programs.steam = {
    enable = true;

    # Useful for per-game Wine/Proton fixes.
    protontricks.enable = true;

    # Makes GE-Proton available in Steam's compatibility tool picker.
    extraCompatPackages = with pkgs; [
      proton-ge-bin
    ];

    remotePlay.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
  };

  programs.gamemode.enable = true;

  environment.systemPackages = with pkgs; [
    mangohud
    protonup-qt
    stardrop
  ];
}
