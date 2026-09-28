{ pkgs, uiScale, ... }:

{
  # Steam and many games still require 32-bit graphics and audio libraries.
  hardware.graphics.enable32Bit = true;
  services.pipewire.alsa.support32Bit = true;

  programs.steam = {
    enable = true;
    package = pkgs.steam.override {
      extraEnv.STEAM_FORCE_DESKTOPUI_SCALING = toString uiScale;
    };
    extraCompatPackages = [ pkgs.proton-ge-bin ];
  };
}
