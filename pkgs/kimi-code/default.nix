{ pkgs }:

pkgs.buildNpmPackage {
  pname = "kimi-code";
  version = "0.14.3";
  src = ./.;
  npmDepsHash = "sha256-DsB5X9qlIznKlTpGDPqu5m2BAKxJSXxgqv+RwZ5F+B0=";
  dontNpmBuild = true;
  nodejs = pkgs.nodejs_24;
}
