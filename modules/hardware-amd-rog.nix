{ pkgs, ... }:

{
  # Ensure the real KMS driver is ready before greetd starts Hyprland.
  boot.initrd.kernelModules = [ "amdgpu" ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  services.asusd.enable = true;

  programs.rog-control-center = {
    enable = true;
    # nixpkgs currently expects a desktop file that asusctl 6.4 no longer ships.
    # Keep the application available without the broken autostart derivation.
    autoStart = false;
  };

  environment.systemPackages = with pkgs; [
    libva-utils
    radeontop
    vulkan-tools
  ];
}
