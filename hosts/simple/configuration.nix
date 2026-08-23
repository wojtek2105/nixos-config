{ pkgs, ... }:

{
  # Reusable, hardware-independent starting point for new workstations.
  # Import it from a real host together with that machine's generated
  # hardware-configuration.nix, boot loader and system.stateVersion.
  imports = [
    ../../modules/common.nix
    ../../modules/desktop.nix
    ../../modules/desktop-shell.nix
    ../../modules/development-core.nix
  ];

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

  users.users.wojtek = {
    isNormalUser = true;
    description = "Polamaniec";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
    shell = pkgs.fish;
  };

  nixpkgs.config.allowUnfree = true;
}
