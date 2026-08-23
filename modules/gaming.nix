{ pkgs, ... }:

{
  programs = {
    steam = {
      enable = true;
      package = pkgs.steam.override {
        extraEnv.STEAM_FORCE_DESKTOPUI_SCALING = "2";
      };
      gamescopeSession.enable = true;
      extraCompatPackages = [ pkgs.proton-ge-bin ];
    };

    gamemode.enable = true;

    gamescope = {
      enable = true;
      capSysNice = true;
    };

    gpu-screen-recorder = {
      enable = true;
      ui.enable = true;
    };
  };
}
