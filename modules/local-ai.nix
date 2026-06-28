{ config, lib, pkgs, ... }:

let
  comfyuiRuntimeLibs = with pkgs; [
    stdenv.cc.cc.lib
    zlib
    libx11
    libxext
    libxcb
  ];
  comfyui-local = pkgs.writeShellScriptBin "comfyui-local" ''
    set -euo pipefail
    cd "$HOME/.hermes/local-image-gen/ComfyUI"
    export LD_LIBRARY_PATH="/run/opengl-driver/lib:${lib.makeLibraryPath comfyuiRuntimeLibs}:''${LD_LIBRARY_PATH:-}"
    exec .venv/bin/python main.py --listen 127.0.0.1 --port 8188 --use-pytorch-cross-attention "$@"
  '';
in

{
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    nvidiaSettings = true;
    open = true;
    package = config.boot.kernelPackages.nvidiaPackages.latest;
  };

  # Python wheels used by ComfyUI are generic Linux binaries. nix-ld is the
  # boring NixOS bridge for that instead of patching every wheel by hand.
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc.lib
      zlib
      libx11
      libxext
      libxcb
    ];
  };

  environment.systemPackages = with pkgs; [
    cudaPackages.cudatoolkit
    comfyui-local
    pciutils
    uv
  ];
}
