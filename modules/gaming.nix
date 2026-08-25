{ pkgs, username, ... }:

{
  # Steam and many games still require 32-bit graphics and ALSA libraries.
  # Keep them behind the gaming capability instead of every AMD/desktop host.
  hardware.graphics.enable32Bit = true;
  services.pipewire.alsa.support32Bit = true;
  # Upstream GameMode requires membership for privileged renice requests.
  users.users.${username}.extraGroups = [ "gamemode" ];

  services.scx = {
    enable = true;
    # Rust schedulers avoid the additional C scheduler closure. Bpfland favors
    # interactive tasks under CPU load and remains suitable for daily desktop
    # use; revisit LAVD after the SCX 1.1.3 freeze regression is resolved.
    # Upstream tracker: https://github.com/sched-ext/scx/issues/3750
    package = pkgs.scx.rustscheds;
    scheduler = "scx_bpfland";
  };

  programs = {
    steam = {
      enable = true;
      package = pkgs.steam.override {
        extraEnv.STEAM_FORCE_DESKTOPUI_SCALING = "2";
      };
      gamescopeSession.enable = true;
      extraCompatPackages = [ pkgs.proton-ge-bin ];
    };

    gamemode = {
      enable = true;
      settings.general = {
        # Performance state is scoped to an active GameMode client and the
        # daemon restores the previous governor/profile when the game exits.
        desiredgov = "performance";
        desiredprof = "performance";
        ioprio = 0;
        inhibit_screensaver = 1;
        # GameMode interprets this as nice -10 for the registered game. The
        # NixOS module grants only gamemoded the capability required to do it.
        renice = 10;
      };
    };

    gamescope = {
      enable = true;
      capSysNice = true;
    };
  };
}
