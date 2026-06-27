{
  lib,
  stdenvNoCC,
  autoPatchelfHook,
  fetchurl,
  fontconfig,
  freetype,
  gcc,
  gdk-pixbuf,
  glib,
  gsettings-desktop-schemas,
  gtk3,
  icu,
  libice,
  libGL,
  libsm,
  libx11,
  libxcursor,
  libxext,
  libxi,
  libxrandr,
  makeShellWrapper,
  openssl,
  unzip,
  wrapGAppsHook3,
  zlib,
}:

stdenvNoCC.mkDerivation rec {
  pname = "stardrop";
  version = "1.9.0";

  src = fetchurl {
    url = "https://github.com/Floogen/Stardrop/releases/download/v${version}/Stardrop-linux-x64.zip";
    hash = "sha256-T+rk7ZDONSgMl1NS8/bZyuA5CQKPIOU88FW4ZUzEO9E=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeShellWrapper
    unzip
    wrapGAppsHook3
  ];

  dontWrapGApps = true;

  buildInputs = [
    fontconfig
    freetype
    gdk-pixbuf
    glib
    gsettings-desktop-schemas
    gtk3
    icu
    libice
    libGL
    libsm
    libx11
    libxcursor
    libxext
    libxi
    libxrandr
    openssl
    gcc.cc.lib
    zlib
  ];

  unpackPhase = ''
    runHook preUnpack
    unzip "$src"
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    install -d "$out/opt/stardrop" "$out/bin" "$out/share/applications"
    cp -R Stardrop/. "$out/opt/stardrop/"
    chmod +x "$out/opt/stardrop/Internal"

    makeShellWrapper "$out/opt/stardrop/Internal" "$out/bin/stardrop" \
      --chdir "$out/opt/stardrop" \
      --run 'uid="$(id -u)"' \
      --run 'export XDG_RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$uid}"' \
      --run 'export DBUS_SESSION_BUS_ADDRESS="''${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XDG_RUNTIME_DIR/bus}"' \
      --run 'export XDG_SESSION_TYPE="''${XDG_SESSION_TYPE:-wayland}"' \
      --run 'export XDG_CURRENT_DESKTOP="''${XDG_CURRENT_DESKTOP:-Hyprland}"' \
      --run 'export WAYLAND_DISPLAY="''${WAYLAND_DISPLAY:-wayland-1}"' \
      --run 'export DISPLAY="''${DISPLAY:-:0}"' \
      --set-default GDK_BACKEND "x11" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath buildInputs}"

    cat > "$out/share/applications/stardrop.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Stardrop
GenericName=Stardew Valley Mod Manager
Comment=Manage Stardew Valley mods and profiles
Exec=$out/bin/stardrop
Terminal=false
Categories=Game;Utility;
EOF

    runHook postInstall
  '';

  postFixup = ''
    wrapProgram "$out/bin/stardrop" "''${gappsWrapperArgs[@]}"
  '';

  meta = {
    description = "Open-source, cross-platform mod manager for Stardew Valley";
    homepage = "https://github.com/Floogen/Stardrop";
    license = lib.licenses.gpl3Only;
    platforms = [ "x86_64-linux" ];
    mainProgram = "stardrop";
  };
}
