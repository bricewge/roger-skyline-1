{ pkgs ? import <nixpkgs> {}}:

let
  mkVM = mods: (import <nixpkgs/nixos/lib/eval-config.nix> {
    modules = [
      # <nixpkgs/nixos/modules/installer/virtualbox-demo.nix>
      <nixpkgs/nixos/modules/virtualisation/virtualbox-image.nix>
      ./configuration.nix
    ] ++ mods;
  }).config.system.build.virtualBoxOVA;
in {
  withTmuxAndVIM = mkVM [
      ({pkgs, ...}: {})
  ];
}
