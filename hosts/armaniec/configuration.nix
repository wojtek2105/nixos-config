{ hostName, inputs, pkgs, userDescription, username, ... }:

{
  imports = [
    # This file must be generated on this exact laptop after its partitions are
    # mounted; it must never contain UUIDs copied from an x86_64 host.
    ./hardware-configuration.nix
    # Provides the Vivobook S 15 device tree, X Elite kernel, initrd modules
    # and the exact Qualcomm/ASUS firmware paths required to boot this model.
    inputs.x1e-nixos-config.nixosModules.x1e
    ../../modules/common.nix
    ../../modules/boot-splash.nix
    ../../modules/desktop.nix
    # Codex and GNU Make are available as native aarch64 packages; this does
    # not add Docker, Agent Manager or an x86 compatibility layer.
    ../../modules/development-core.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 1;

  # Include the Qualcomm firmware delivered by nixpkgs. Do not add a board DTB,
  # kernel parameter or backlight name before checking the actual S 15 revision.
  hardware.enableRedistributableFirmware = true;
  hardware.asus-vivobook-s15.enable = true;

  networking.hostName = hostName;
  networking.networkmanager.enable = true;

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

  # Set on the first installation only; do not change during normal upgrades.
  system.stateVersion = "26.05";
}
