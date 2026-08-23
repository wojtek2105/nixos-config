{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common.nix
    ../../modules/desktop.nix
    ../../modules/desktop-shell.nix
    ../../modules/development.nix
    ../../modules/gaming.nix
    ../../modules/hardware-amd-rog.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "polamaniec";
  networking.networkmanager.enable = true;

  home-manager.extraSpecialArgs.replayConfig = {
    captureSource = "eDP-2";
    fps = 60;
    seconds = 120;
    videoCodec = "hevc";
    videoBitrate = 25000;
    audioCodec = "opus";
  };

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "pl_PL.UTF-8";
    LC_IDENTIFICATION = "pl_PL.UTF-8";
    LC_MEASUREMENT = "pl_PL.UTF-8";
    LC_MONETARY = "pl_PL.UTF-8";
    LC_NAME = "pl_PL.UTF-8";
    LC_NUMERIC = "pl_PL.UTF-8";
    LC_PAPER = "pl_PL.UTF-8";
    LC_TELEPHONE = "pl_PL.UTF-8";
    LC_TIME = "pl_PL.UTF-8";
  };

  services.xserver.xkb = {
    layout = "pl";
    variant = "";
  };

  console.keyMap = "pl2";

  users.users.wojtek = {
    isNormalUser = true;
    description = "Polamaniec";
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.fish;
  };

  nixpkgs.config.allowUnfree = true;

  # Never change after the first installation without reading the NixOS manual.
  system.stateVersion = "26.05";
}
