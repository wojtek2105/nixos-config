{ pkgs, username, ... }:

{
  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };

  services.greetd = {
    enable = true;
    settings = {
      initial_session = {
        command = "${pkgs.uwsm}/bin/uwsm start -e -D Hyprland hyprland.desktop";
        user = username;
      };

      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --remember-user-session --sessions /run/current-system/sw/share/wayland-sessions";
        user = "greeter";
      };
    };
  };

  programs.thunar = {
    enable = true;
    plugins = with pkgs; [
      thunar-archive-plugin
      thunar-volman
    ];
  };

  programs.dconf.enable = true;
  security.polkit.enable = true;
  security.rtkit.enable = true;

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  services = {
    gvfs.enable = true;
    tumbler.enable = true;

    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;

      extraConfig.pipewire."92-audiophile" = {
        "context.properties" = {
          "default.clock.rate" = 48000;
          "default.clock.allowed-rates" = [
            44100
            48000
            88200
            96000
            176400
            192000
            352800
            384000
          ];
          "resample.quality" = 10;
        };
      };
    };
  };

  fonts = {
    packages = with pkgs; [
      inter
      nerd-fonts.commit-mono
      noto-fonts-color-emoji
    ];
    fontconfig.defaultFonts = {
      sansSerif = [ "Inter" ];
      monospace = [ "CommitMono Nerd Font Mono" ];
      emoji = [ "Noto Color Emoji" ];
    };
    fontconfig = {
      antialias = true;
      hinting = {
        enable = true;
        autohint = false;
        style = "medium";
      };
      subpixel = {
        rgba = "rgb";
        lcdfilter = "default";
      };
    };
  };
}
