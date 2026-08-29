{ hostName, pkgs, userDescription, username, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common.nix
    ../../modules/desktop.nix
    ../../modules/lan-mouse.nix
    ../../modules/development-core.nix
    ../../modules/hardware-amd-gpu.nix
  ];

  # RDNA 4 support benefits from the newest kernel carried by the pinned
  # nixpkgs. No ASUS laptop services or power-profile daemons are imported.
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 1;

  networking.hostName = hostName;
  networking.networkmanager.enable = true;

  # White Monster receives keyboard and mouse events from Rog Polamaniec.
  # Approve Rog's fingerprint once in Lan Mouse after both hosts are active.
  services.lanMouse = {
    enable = true;
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
      "networkmanager"
      "wheel"
    ];
    shell = pkgs.fish;
  };

  nixpkgs.config.allowUnfree = true;

  # Keep this aligned with the version used for the first White Monster
  # installation. Do not change it during ordinary upgrades.
  system.stateVersion = "26.05";
}
