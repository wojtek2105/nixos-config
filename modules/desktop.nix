{ desktopTheme, hostName, lib, pkgs, username, ... }:

let
  c = desktopTheme.colors;
  tuigreetTheme = lib.concatStringsSep ";" [
    "border=bright-magenta"
    "text=white"
    "time=yellow"
    "container=black"
    "title=bright-magenta"
    "greet=bright-white"
    "prompt=yellow"
    "input=bright-white"
    "action=bright-black"
    "button=bright-magenta"
  ];

  tuigreetCommand = lib.escapeShellArgs [
    "${pkgs.tuigreet}/bin/tuigreet"
    "--cmd"
    "${pkgs.uwsm}/bin/uwsm start -e -D Hyprland hyprland.desktop"
    "--user"
    username
    "--remember"
    "--remember-user-session"
    "--user-menu"
    "--sessions"
    "/run/current-system/sw/share/wayland-sessions"
    "--title"
    "--custom-title"
    " Zaloguj się "
    "--greeting"
    "RED  >  GREEN  >  REFACTOR  |  ${hostName}"
    "--greet-align"
    "center"
    "--time"
    "--time-format"
    "%A, %d %B  %H:%M"
    "--width"
    "54"
    "--window-padding"
    "2"
    "--container-padding"
    "2"
    "--prompt-padding"
    "1"
    "--asterisks"
    "--asterisks-char"
    "●"
    "--theme"
    tuigreetTheme
    # A quiet TDD-like stream: green test heads, Biscuit-pink active checks and
    # a dark failure trail. Twelve FPS keeps the greeter responsive and cheap.
    "--background"
    "matrix"
    "--background-fps"
    "12"
    "--matrix-colors"
    "#${c.green},#${c.accent},#${c.selection}"
    "--matrix-length"
    "4,12"
    "--matrix-speed"
    "0.22,0.68"
    "--power-shutdown"
    "${pkgs.systemd}/bin/systemctl poweroff"
    "--power-reboot"
    "${pkgs.systemd}/bin/systemctl reboot"
  ];
in
{
  # Map Tuigreet's ANSI roles onto the canonical Biscuit palette. This also
  # keeps recovery VTs visually coherent without duplicating theme literals.
  console.colors = [
    c.background
    c.red
    c.green
    c.yellow
    c.blue
    c.magenta
    c.violet
    c.foreground
    c.muted
    c.orange
    c.olive
    c.yellow
    c.violet
    c.accent
    c.subtle
    c.bright
  ];

  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };

  services.greetd = {
    enable = true;
    # Tuigreet owns VT1 after autologin ends; keep boot messages from drawing
    # over its centered form and corrupting the terminal UI.
    useTextGreeter = true;
    settings = {
      initial_session = {
        command = "${pkgs.uwsm}/bin/uwsm start -e -D Hyprland hyprland.desktop";
        user = username;
      };

      default_session = {
        command = tuigreetCommand;
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
      pulse.enable = true;

      extraConfig.pipewire."92-balanced-desktop" = {
        "context.properties" = {
          "default.clock.rate" = 48000;
          # Desktop applications and games use 44.1 or 48 kHz. Avoid switching
          # the graph to costly high-resolution rates that provide no gaming
          # benefit and make every active node process more samples.
          "default.clock.allowed-rates" = [
            44100
            48000
          ];
          # PipeWire's balanced default keeps resampling inexpensive while
          # retaining transparent quality for normal playback and capture.
          "resample.quality" = 4;
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
