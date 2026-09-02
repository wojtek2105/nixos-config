{ hostName, pkgs, userDescription, username, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common.nix
    ../../modules/boot-splash.nix
    ../../modules/desktop.nix
    ../../modules/lan-mouse.nix
    ../../modules/development-core.nix
    ../../modules/hardware-amd-gpu.nix
    ../../modules/hardware-asus-laptop.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # Keep recovery generations selectable without paying the default five-second
  # delay on every normal boot.
  boot.loader.timeout = 1;

  networking.hostName = hostName;
  networking.networkmanager.enable = true;

  # Rog Polamaniec owns the physical keyboard and mouse and shares them with
  # White Monster without streaming video. Lan Mouse uses the right screen
  # edge; its host name must match White Monster's networking.hostName value.
  services.lanMouse = {
    enable = true;
    peerHost = "white-monster";
  };

  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
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

  users.users.${username} = {
    isNormalUser = true;
    description = userDescription;
    extraGroups = [
      # Voxtype's built-in Caps Lock hotkey reads evdev directly. Membership
      # exposes raw input events, so keep it limited to this trusted desktop
      # account and do not add it to shared profiles.
      "input"
      "networkmanager"
      "wheel"
    ];
    shell = pkgs.fish;
  };

  nixpkgs.config.allowUnfree = true;

  # Never change after the first installation without reading the NixOS manual.
  system.stateVersion = "26.05";
}
