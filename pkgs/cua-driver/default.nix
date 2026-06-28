{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  alsa-lib,
  at-spi2-core,
  cairo,
  dbus,
  expat,
  fontconfig,
  freetype,
  glib,
  gtk3,
  libGL,
  libX11,
  libXScrnSaver,
  libXcursor,
  libXdamage,
  libXext,
  libXfixes,
  libXi,
  libXinerama,
  libXrandr,
  libXtst,
  libdrm,
  libgbm,
  libinput,
  libpulseaudio,
  libxkbcommon,
  libxcb,
  nspr,
  nss,
  pango,
  systemd,
  wayland,
}:

stdenv.mkDerivation rec {
  pname = "cua-driver";
  version = "0.6.8";

  src = fetchurl {
    url = "https://github.com/trycua/cua/releases/download/cua-driver-rs-v${version}/cua-driver-rs-${version}-linux-x86_64-binary.tar.gz";
    hash = "sha256-3ohcatgrXhDtAhO+RkLdp0tZIpkK1gAutbxIHV2JwFs=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    alsa-lib
    at-spi2-core
    cairo
    dbus
    expat
    fontconfig
    freetype
    glib
    gtk3
    libGL
    libX11
    libXScrnSaver
    libXcursor
    libXdamage
    libXext
    libXfixes
    libXi
    libXinerama
    libXrandr
    libXtst
    libdrm
    libgbm
    libinput
    libpulseaudio
    libxkbcommon
    libxcb
    nspr
    nss
    pango
    stdenv.cc.cc.lib
    systemd
    wayland
  ];

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    install -Dm755 cua-driver "$out/bin/cua-driver"

    runHook postInstall
  '';

  postFixup = ''
    wrapProgram "$out/bin/cua-driver" \
      --prefix PATH : ${lib.makeBinPath [ dbus ]}
  '';

  meta = {
    description = "Cross-platform computer-use driver used by Hermes/agent desktop automation";
    homepage = "https://github.com/trycua/cua";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "cua-driver";
  };
}
