{ pkgs, ... }:

{
  # On-demand inspection tools; daily metrics already come from Ironbar/btop.
  environment.systemPackages = with pkgs; [
    libva-utils
    radeontop
    vulkan-tools
  ];
}
