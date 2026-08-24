{ pkgs, ... }:

{
  # Load the real KMS driver before greetd starts Hyprland. This prevents
  # the compositor from seeing only simpledrm during early startup.
  boot.initrd.kernelModules = [ "amdgpu" ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  environment.systemPackages = with pkgs; [
    libva-utils
    radeontop
    vulkan-tools
  ];
}
