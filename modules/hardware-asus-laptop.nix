{ pkgs, ... }:

{
  # asus-armoury entered mainline after the default 6.18 kernel. It exposes
  # firmware attributes used by current asusctl releases on this GA402RK.
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelModules = [ "asus-armoury" ];

  services.asusd.enable = true;
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;

  programs.rog-control-center = {
    enable = true;
    # nixpkgs currently expects a desktop file that asusctl 6.4 no longer ships.
    # Keep the application available without the broken autostart derivation.
    autoStart = false;
  };
}
