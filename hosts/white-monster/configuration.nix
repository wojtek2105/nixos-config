{ lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/host-base.nix
    ../../modules/minimal-desktop.nix
  ];

  # This portable installation must boot through the UEFI fallback path and
  # must not register itself in the firmware of whichever PC starts it.
  boot.loader = {
    systemd-boot.enable = lib.mkForce false;
    efi.canTouchEfiVariables = lib.mkForce false;
    grub = {
      enable = true;
      devices = [ "nodev" ];
      efiSupport = true;
      efiInstallAsRemovable = true;
    };
  };

  # Keep NetworkManager for wired Ethernet but do not let it configure Wi-Fi.
  networking.networkmanager.unmanaged = [
    "interface-name:wlan*"
    "interface-name:wlp*"
  ];
}
