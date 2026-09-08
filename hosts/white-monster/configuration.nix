{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/host-base.nix
  ];

  environment.systemPackages = [
    pkgs.gnumake
    pkgs.vim
  ];
}
