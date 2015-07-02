{ config ? {}, pkgs ? import ./nixpkgs }:

with (pkgs {}).lib;

(pkgs {
  config = recursiveUpdate config (import ./config.nix);
})
