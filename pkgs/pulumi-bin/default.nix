{
  lib,
  stdenvNoCC,
  fetchurl,
}:

stdenvNoCC.mkDerivation rec {
  pname = "pulumi-bin";
  version = "3.246.0";

  src = fetchurl {
    url = "https://github.com/pulumi/pulumi/releases/download/v${version}/pulumi-v${version}-linux-x64.tar.gz";
    hash = "sha256-JJp5dVhxjKpi9p5yWbpqivDW2jviyuwx2soXz7u2wE8=";
  };

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    cp * $out/bin/

    runHook postInstall
  '';

  meta = {
    description = "Pulumi infrastructure as code CLI";
    homepage = "https://www.pulumi.com";
    license = lib.licenses.asl20;
    mainProgram = "pulumi";
    platforms = [ "x86_64-linux" ];
  };
}
