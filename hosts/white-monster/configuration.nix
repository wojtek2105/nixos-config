{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/host-base.nix
  ];

  # Keep NetworkManager for wired Ethernet but do not let it configure Wi-Fi.
  networking.networkmanager.unmanaged = [
    "interface-name:wlan*"
    "interface-name:wlp*"
  ];
}
