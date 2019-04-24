# bloodhound is not broken with:
# https://hydra.nixos.org/build/86299724#tabs-summary
with import (fetchTarball {
  url = https://github.com/NixOS/nixpkgs/archive/0b0c67e5378ccc4f4eef3a7e88eb2acb1127d50f.tar.gz;
  sha256 = "11834w0vbc6i2avg3pz2315b2v6xka5132jlr28iymnk2ysd9acy";
}) {};

let
  drv = (haskellPackages.override {
  #  overrides = self: super: rec {
  #   # fix https://hydra.nixos.org/build/86436153
  #    bloodhound = self.callPackage ./nix/bloodhound.nix {
  #     containers = self.callPackage ./nix/containers.nix {};
  #    };
    # aeson = self.callPackage ./nix/aeson.nix {};
  #  };
  }).callCabal2nix "espurge" ./. {};
in if lib.inNixShell then drv.env.overrideAttrs (old: {
  buildInputs = old.buildInputs ++ [ haskellPackages.ghcid cabal-install ];
}) else drv
