{ pkgs, username, ... }:

let
  lsfg-vk-v2 = pkgs.callPackage ../packages/lsfg-vk-v2.nix { };
in

{
  environment.systemPackages = [
    # Official v2 release: layer, 32-bit layer, Qt UI and CLI stay in sync.
    lsfg-vk-v2
  ];
  # Upstream GameMode requires membership for privileged renice requests.
  users.users.${username}.extraGroups = [ "gamemode" ];

  programs = {
    steam.gamescopeSession.enable = true;

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
