{ ... }:

{
  imports = [
    ../simple/configuration.nix
    ./hardware-configuration.nix
    ../../modules/development.nix
    ../../modules/gaming.nix
    ../../modules/hardware-amd-rog.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "rog-polamaniec";

  # Never change after the first installation without reading the NixOS manual.
  system.stateVersion = "26.05";
}
