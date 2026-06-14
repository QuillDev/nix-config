{ pkgs }:

pkgs.buildNpmPackage {
  pname = "kimi-code";
  version = "0.14.2";
  src = ./.;
  npmDepsHash = "sha256-Wsqvci5ZnGVV/iZ67l1WH8tcsnOGMK6jO4p2p4sFcjo=";
  dontNpmBuild = true;
  nodejs = pkgs.nodejs_24;
}
